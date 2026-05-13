from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import asyncio
import csv
import json
import os
import time
from pathlib import Path as SysPath
from datetime import datetime
from statistics import mean

from farmer_adviser import ask_farm_advisor_multi, compose_farm_advisor_prompts

app = FastAPI(
    title="CysecAgri Farm Advisor API",
    description="LLM-based farm advisor for temperature & moisture data (multi-device)",
    version="0.4.0",
)

# ---- Built-in dataset farm settings ----
FARM3_DEVICE_ID = "farm3_dataset"
FARM4_DEVICE_ID = "farm4_dataset"
FARM5_DEVICE_ID = "farm5_dataset"

FARM3_DEFAULT_LABEL = "Farm 3"
FARM4_DEFAULT_LABEL = "Farm 4"
FARM5_DEFAULT_LABEL = "Farm 5"

FARM3_CSV_PATH = os.getenv("FARM3_CSV_PATH", "/Users/sayontanibose/farm3_dataset.csv")
CROP_YIELD_CSV_PATH = os.getenv("CROP_YIELD_CSV_PATH", "/Users/sayontanibose/crop_yield.csv")
MIDWEST_TIMESERIES_CSV_PATH = os.getenv("MIDWEST_TIMESERIES_CSV_PATH", "/Users/sayontanibose/midwest_timeseries.csv")
SOILPH_CSV_PATH = os.getenv("SOILPH_CSV_PATH", "/Users/sayontanibose/soilph.csv")

FARM3_LIMIT = int(os.getenv("FARM3_LIMIT", "15"))
FARM4_LIMIT = int(os.getenv("FARM4_LIMIT", "14"))
FARM5_LIMIT = int(os.getenv("FARM5_LIMIT", "1"))

FARM3_ENABLE = os.getenv("FARM3_ENABLE", "1").strip() not in {"0", "false", "False", "no", "NO"}
FARM4_ENABLE = os.getenv("FARM4_ENABLE", "1").strip() not in {"0", "false", "False", "no", "NO"}
FARM5_ENABLE = os.getenv("FARM5_ENABLE", "1").strip() not in {"0", "false", "False", "no", "NO"}


EVAL_LOG_DIR = os.getenv("EVAL_LOG_DIR", "./evaluation_logs")
REQUEST_METRICS_CSV = os.path.join(EVAL_LOG_DIR, "farm_advisor_metrics.csv")
REQUEST_METRICS_JSONL = os.path.join(EVAL_LOG_DIR, "farm_advisor_metrics.jsonl")
SUMMARY_METRICS_JSON = os.path.join(EVAL_LOG_DIR, "farm_advisor_summary.json")
os.makedirs(EVAL_LOG_DIR, exist_ok=True)


_FARM3_CACHE: Dict[str, Any] = {"mtime": None, "limit": None, "rows": []}
_FARM4_CACHE: Dict[str, Any] = {"mtime_midwest": None, "mtime_yield": None, "limit": None, "rows": [], "context": ""}
_FARM5_CACHE: Dict[str, Any] = {"mtime": None, "limit": None, "rows": [], "context": ""}


def _to_float(x):
    try:
        return float(x) if x not in (None, "", "NA", "NaN") else None
    except Exception:
        return None


def estimate_tokens(text: str) -> int:
    text = text or ""
    return max(1, int(round(len(text) / 4))) if text else 0


def calculate_accuracy_metrics(quality: Dict[str, float]) -> Dict[str, float]:
    accuracy_score = round(quality["overall"], 4)
    accuracy_percent = round(accuracy_score * 100.0, 2)
    return {
        "accuracy_score": accuracy_score,
        "accuracy_percent": accuracy_percent,
    }




def _parse_any_datetime(text: str) -> Optional[datetime]:
    if not text:
        return None
    text = text.strip()
    for fmt in (
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
        "%m/%d/%Y %H:%M",
        "%m/%d/%Y",
    ):
        try:
            return datetime.strptime(text, fmt)
        except Exception:
            pass
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except Exception:
        return None


def _find_first_key(row: Dict[str, Any], candidates: List[str]) -> Optional[str]:
    lowered = {str(k).strip().lower(): k for k in row.keys()}
    for cand in candidates:
        key = lowered.get(cand.lower())
        if key is not None:
            return key
    return None


class Reading(BaseModel):
    timestamp: str
    temperature: Optional[float] = None
    moisture: Optional[float] = None


class MultiAdviceRequest(BaseModel):
    device_ids: List[str] = Field(..., min_length=1)
    farm_labels: Dict[str, str] = Field(default_factory=dict)
    prompt_id: str = Field(..., min_length=1)
    readings_by_device: Dict[str, List[Reading]] = Field(default_factory=dict)
    question: str = ""


class MultiAdviceResponse(BaseModel):
    answer: str


@app.get("/health")
def health_check() -> Dict[str, Any]:
    return {"status": "ok"}


@app.get("/farm3/readings")
def farm3_readings(limit: int = FARM3_LIMIT) -> Dict[str, Any]:
    if not FARM3_ENABLE:
        raise HTTPException(status_code=404, detail="Farm 3 disabled")
    rows = load_farm3_readings(FARM3_CSV_PATH, limit)
    if not rows:
        raise HTTPException(status_code=404, detail="Farm 3 dataset not found or empty")
    return {"device_id": FARM3_DEVICE_ID, "label": FARM3_DEFAULT_LABEL, "readings": rows}


@app.get("/farm4/readings")
def farm4_readings(limit: int = FARM4_LIMIT) -> Dict[str, Any]:
    if not FARM4_ENABLE:
        raise HTTPException(status_code=404, detail="Farm 4 disabled")
    rows = load_farm4_proxy_readings(MIDWEST_TIMESERIES_CSV_PATH, limit)
    if not rows:
        raise HTTPException(status_code=404, detail="Farm 4 dataset not found or empty")
    return {"device_id": FARM4_DEVICE_ID, "label": FARM4_DEFAULT_LABEL, "readings": rows}


@app.get("/farm5/readings")
def farm5_readings(limit: int = FARM5_LIMIT) -> Dict[str, Any]:
    if not FARM5_ENABLE:
        raise HTTPException(status_code=404, detail="Farm 5 disabled")
    rows = load_farm5_proxy_readings(SOILPH_CSV_PATH, limit)
    if not rows:
        raise HTTPException(status_code=404, detail="Farm 5 dataset not found or empty")
    return {"device_id": FARM5_DEVICE_ID, "label": FARM5_DEFAULT_LABEL, "readings": rows}


def load_farm3_readings(csv_path: str, limit: int = 15) -> List[Dict[str, Any]]:
    p = SysPath(csv_path)
    if not p.exists():
        return []
    try:
        mtime = p.stat().st_mtime
    except Exception:
        mtime = None
    if _FARM3_CACHE.get("mtime") == mtime and _FARM3_CACHE.get("limit") == limit and _FARM3_CACHE.get("rows"):
        return _FARM3_CACHE["rows"]

    rows: List[Dict[str, Any]] = []
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            ts_key = _find_first_key(row, ["timestamp", "date", "day", "datetime"])
            moist_key = _find_first_key(row, [
                "moisture", "soil_moisture", "sms-2.0in", "sms-4.0in", "sms_2", "sms_4",
                "sm_2", "sm_4", "soil moisture"
            ])
            temp_key = _find_first_key(row, [
                "temperature", "temp", "soil_temp", "stp-2.0in", "stp-4.0in", "soil temperature"
            ])
            if not ts_key:
                continue
            raw_ts = str(row.get(ts_key, "")).strip()
            dt = _parse_any_datetime(raw_ts)
            ts = dt.isoformat() if dt else raw_ts
            rows.append(
                {
                    "timestamp": ts,
                    "moisture": _to_float(row.get(moist_key)) if moist_key else None,
                    "temperature": _to_float(row.get(temp_key)) if temp_key else None,
                }
            )

    rows.sort(key=lambda r: r.get("timestamp", ""))
    rows = rows[-max(1, limit):]
    _FARM3_CACHE.update({"mtime": mtime, "limit": limit, "rows": rows})
    return rows


def load_farm4_proxy_readings(csv_path: str, limit: int = 14) -> List[Dict[str, Any]]:
    p = SysPath(csv_path)
    if not p.exists():
        return []
    try:
        mtime = p.stat().st_mtime
    except Exception:
        mtime = None
    if _FARM4_CACHE.get("mtime_midwest") == mtime and _FARM4_CACHE.get("limit") == limit and _FARM4_CACHE.get("rows"):
        return _FARM4_CACHE["rows"]

    rows: List[Dict[str, Any]] = []
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            ts = str(row.get("day") or row.get("date") or row.get("timestamp") or "").strip()
            dt = _parse_any_datetime(ts)
            if not ts:
                continue
            rows.append(
                {
                    "timestamp": dt.isoformat() if dt else ts,
                    "max_temp_f": _to_float(row.get("max_temp_f") or row.get("max_temp")),
                    "min_temp_f": _to_float(row.get("min_temp_f") or row.get("min_temp")),
                    "precip_in": _to_float(row.get("precip_in") or row.get("precip")),
                    "avg_rh": _to_float(row.get("avg_rh") or row.get("humidity") or row.get("relative_humidity")),
                }
            )

    rows.sort(key=lambda r: r.get("timestamp", ""))
    rows = rows[-max(1, limit):]
    _FARM4_CACHE.update({"mtime_midwest": mtime, "limit": limit, "rows": rows})
    return rows


def load_farm5_proxy_readings(csv_path: str, limit: int = 1) -> List[Dict[str, Any]]:
    p = SysPath(csv_path)
    if not p.exists():
        return []
    try:
        mtime = p.stat().st_mtime
    except Exception:
        mtime = None
    if _FARM5_CACHE.get("mtime") == mtime and _FARM5_CACHE.get("limit") == limit and _FARM5_CACHE.get("rows"):
        return _FARM5_CACHE["rows"]

    rows: List[Dict[str, Any]] = []
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(
                {
                    "timestamp": datetime.utcnow().isoformat(),
                    "station": row.get("station") or row.get("Station"),
                    "soil_ph": _to_float(row.get("soil_ph") or row.get("soilph") or row.get("ph")),
                    "organic_carbon": _to_float(row.get("organic_carbon") or row.get("organic carbon")),
                    "nitrogen": _to_float(row.get("nitrogen")),
                }
            )
    rows = rows[-max(1, limit):]
    _FARM5_CACHE.update({"mtime": mtime, "limit": limit, "rows": rows})
    return rows


def build_farm4_context() -> str:
    crop_path = SysPath(CROP_YIELD_CSV_PATH)
    midwest_path = SysPath(MIDWEST_TIMESERIES_CSV_PATH)
    crop_mtime = crop_path.stat().st_mtime if crop_path.exists() else None
    midwest_mtime = midwest_path.stat().st_mtime if midwest_path.exists() else None
    if _FARM4_CACHE.get("mtime_midwest") == midwest_mtime and _FARM4_CACHE.get("mtime_yield") == crop_mtime and _FARM4_CACHE.get("context"):
        return _FARM4_CACHE["context"]

    climate_rows = load_farm4_proxy_readings(MIDWEST_TIMESERIES_CSV_PATH, 14)
    yield_rows: List[Dict[str, Any]] = []
    if crop_path.exists():
        with crop_path.open("r", encoding="utf-8", errors="replace", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                year = str(row.get("Year") or row.get("year") or "").strip()
                value = _to_float(row.get("Value") or row.get("value"))
                if year and value is not None:
                    yield_rows.append({"year": year, "value": value})
    yield_rows.sort(key=lambda r: r["year"])
    yield_rows = yield_rows[-5:]

    temps = [r["max_temp_f"] for r in climate_rows if r.get("max_temp_f") is not None]
    humid = [r["avg_rh"] for r in climate_rows if r.get("avg_rh") is not None]
    rain_days = 0
    if midwest_path.exists():
        with midwest_path.open("r", encoding="utf-8", errors="replace", newline="") as f:
            all_rows = list(csv.DictReader(f))[-14:]
            for row in all_rows:
                precip = _to_float(row.get("precip_in") or row.get("precip"))
                if precip is not None and precip > 0.05:
                    rain_days += 1

    yield_text = ", ".join(f"{r['year']}: {r['value']} bu/acre" for r in yield_rows) if yield_rows else "no recent yield rows found"
    context = (
        f"Farm 4 context: Midwest climate + yield dataset. "
        f"Last 14 climate rows show max temp avg {round(sum(temps)/len(temps),1) if temps else 'NA'} F, "
        f"avg humidity {round(sum(humid)/len(humid),1) if humid else 'NA'}%, "
        f"rain on {rain_days} of the last 14 days. "
        f"Recent Iowa corn yields: {yield_text}."
    )
    _FARM4_CACHE.update({"mtime_midwest": midwest_mtime, "mtime_yield": crop_mtime, "context": context})
    return context


def build_farm5_context() -> str:
    p = SysPath(SOILPH_CSV_PATH)
    if not p.exists():
        return "Farm 5 context not available."
    try:
        mtime = p.stat().st_mtime
    except Exception:
        mtime = None
    if _FARM5_CACHE.get("mtime") == mtime and _FARM5_CACHE.get("context"):
        return _FARM5_CACHE["context"]

    station = "Iowa"
    soil_ph = organic_carbon = nitrogen = None
    with p.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            station = str(row.get("station") or row.get("Station") or "Iowa").strip() or "Iowa"
            soil_ph = _to_float(row.get("soil_ph") or row.get("soilph") or row.get("ph"))
            organic_carbon = _to_float(row.get("organic_carbon") or row.get("organic carbon"))
            nitrogen = _to_float(row.get("nitrogen"))
            break

    context = (
        f"Farm 5 context: soil profile dataset for {station}. "
        f"Soil pH {soil_ph if soil_ph is not None else 'NA'}, "
        f"organic carbon {organic_carbon if organic_carbon is not None else 'NA'}, "
        f"nitrogen {nitrogen if nitrogen is not None else 'NA'}."
    )
    _FARM5_CACHE.update({"mtime": mtime, "context": context})
    return context


def maybe_inject_builtin_datasets(body: MultiAdviceRequest) -> Dict[str, str]:
    context_by_farm: Dict[str, str] = {}

    if FARM3_ENABLE and FARM3_DEVICE_ID in body.device_ids:
        if FARM3_DEVICE_ID not in body.readings_by_device or not body.readings_by_device[FARM3_DEVICE_ID]:
            rows = load_farm3_readings(FARM3_CSV_PATH, FARM3_LIMIT)
            if rows:
                body.farm_labels.setdefault(FARM3_DEVICE_ID, FARM3_DEFAULT_LABEL)
                body.readings_by_device[FARM3_DEVICE_ID] = [Reading(**r) for r in rows]
                context_by_farm[FARM3_DEVICE_ID] = "Farm 3 context: SCAN recent moisture and temperature dataset."

    if FARM4_ENABLE and FARM4_DEVICE_ID in body.device_ids:
        body.farm_labels.setdefault(FARM4_DEVICE_ID, FARM4_DEFAULT_LABEL)
        if FARM4_DEVICE_ID not in body.readings_by_device or not body.readings_by_device[FARM4_DEVICE_ID]:
            rows = load_farm4_proxy_readings(MIDWEST_TIMESERIES_CSV_PATH, FARM4_LIMIT)
            if rows:
                body.readings_by_device[FARM4_DEVICE_ID] = [Reading(**r) for r in rows]
        context_by_farm[FARM4_DEVICE_ID] = build_farm4_context()

    if FARM5_ENABLE and FARM5_DEVICE_ID in body.device_ids:
        body.farm_labels.setdefault(FARM5_DEVICE_ID, FARM5_DEFAULT_LABEL)
        context_by_farm[FARM5_DEVICE_ID] = build_farm5_context()

    return context_by_farm



def _safe_lower(text: str) -> str:
    return (text or "").strip().lower()


def _contains_any(text: str, keywords: List[str]) -> bool:
    t = _safe_lower(text)
    return any(k in t for k in keywords)


def _extract_latest_numeric(readings: List[Dict[str, Any]], field: str) -> Optional[float]:
    if not readings:
        return None
    rows = sorted(readings, key=lambda r: r.get("timestamp", ""), reverse=True)
    for row in rows:
        value = _to_float(row.get(field))
        if value is not None:
            return value
    return None


def _score_relevance(prompt_id: str, answer: str) -> float:
    answer_l = _safe_lower(answer)
    prompt_keywords = {
        "IMMEDIATE_IRRIGATION": ["irrigation", "water", "moisture", "soil moisture"],
        "HEAT_STRESS_ALERT": ["heat", "stress", "temperature", "moisture"],
        "YIELD_IMPACT": ["yield", "pressure", "production", "potential"],
        "CROP_RESPONSE": ["response", "trend", "condition", "monitor"],
        "SOIL_NUTRIENT": ["soil", "ph", "nitrogen", "organic carbon"],
    }
    expected = prompt_keywords.get(prompt_id, [])
    if not expected:
        return 0.75
    hits = sum(1 for k in expected if k in answer_l)
    return min(1.0, hits / max(2, len(expected)))


def _score_actionability(answer: str) -> float:
    answer_l = _safe_lower(answer)
    action_words = [
        "check", "monitor", "irrigate", "apply", "adjust", "inspect",
        "watch", "correct", "manage", "sample", "schedule"
    ]
    hits = sum(1 for w in action_words if w in answer_l)
    bullet_bonus = 0.15 if "- " in answer else 0.0
    return min(1.0, min(0.85, hits / 4.0) + bullet_bonus)


def _score_clarity(answer: str) -> float:
    if not answer or not answer.strip():
        return 0.0

    sections = 0
    for label in [
        "Irrigation decision:",
        "What is driving this decision:",
        "Action to take now:",
        "Field check right now:",
        "Heat stress assessment:",
        "Immediate management:",
        "Yield outlook:",
        "Management priority:",
        "Crop response summary:",
        "What this means for management:",
        "Soil limitation summary:",
        "Management direction:",
        "Agronomist takeaway:",
    ]:
        if label.lower() in answer.lower():
            sections += 1

    if sections >= 3:
        return 1.0
    if sections == 2:
        return 0.8
    if sections == 1:
        return 0.6
    return 0.4


def _score_correctness(prompt_id: str,
                       answer: str,
                       readings_by_device: Dict[str, List[Dict[str, Any]]],
                       context_by_farm: Dict[str, str]) -> float:
    answer_l = _safe_lower(answer)
    checks = []

    all_moisture = []
    all_temp = []
    for _, rows in readings_by_device.items():
        m = _extract_latest_numeric(rows, "moisture")
        t = _extract_latest_numeric(rows, "temperature")
        if m is not None:
            all_moisture.append(m)
        if t is not None:
            all_temp.append(t)

    avg_moist = mean(all_moisture) if all_moisture else None
    avg_temp = mean(all_temp) if all_temp else None

    if prompt_id == "IMMEDIATE_IRRIGATION":
        if avg_moist is not None:
            if avg_moist < 30:
                checks.append(_contains_any(answer_l, ["irrigat", "water", "dry", "low moisture"]))
            elif avg_moist >= 40:
                checks.append(_contains_any(answer_l, ["wait", "monitor", "hold off"]))
        if avg_temp is not None and avg_temp > 32:
            checks.append(_contains_any(answer_l, ["heat", "temperature", "stress"]))

    elif prompt_id == "HEAT_STRESS_ALERT":
        if avg_temp is not None:
            if avg_temp > 32:
                checks.append(_contains_any(answer_l, ["moderate", "high", "heat stress", "stress"]))
            else:
                checks.append(_contains_any(answer_l, ["low", "limited", "watch"]))
        if avg_moist is not None and avg_moist < 30:
            checks.append(_contains_any(answer_l, ["moisture", "dry", "water deficit"]))

    elif prompt_id == "YIELD_IMPACT":
        if avg_moist is not None and avg_moist < 30:
            checks.append(_contains_any(answer_l, ["yield", "pressure", "risk", "concern"]))
        if avg_temp is not None and avg_temp > 32:
            checks.append(_contains_any(answer_l, ["heat", "stress", "pressure"]))

    elif prompt_id == "CROP_RESPONSE":
        checks.append(_contains_any(answer_l, ["stable", "recover", "pressure", "trend", "monitor"]))

    elif prompt_id == "SOIL_NUTRIENT":
        ctx = " ".join(context_by_farm.values()).lower()
        if "ph" in ctx:
            checks.append("ph" in answer_l)
        if "nitrogen" in ctx:
            checks.append("nitrogen" in answer_l)
        if "organic carbon" in ctx:
            checks.append("organic carbon" in answer_l or "carbon" in answer_l)

    if not checks:
        return 0.75

    return sum(1.0 for c in checks if c) / len(checks)


def compute_advisory_quality_score(prompt_id: str,
                                   answer: str,
                                   readings_by_device: Dict[str, List[Dict[str, Any]]],
                                   context_by_farm: Dict[str, str]) -> Dict[str, float]:
    relevance = _score_relevance(prompt_id, answer)
    correctness = _score_correctness(prompt_id, answer, readings_by_device, context_by_farm)
    actionability = _score_actionability(answer)
    clarity = _score_clarity(answer)
    overall = (relevance + correctness + actionability + clarity) / 4.0

    return {
        "relevance": round(relevance, 4),
        "correctness": round(correctness, 4),
        "actionability": round(actionability, 4),
        "clarity": round(clarity, 4),
        "overall": round(overall, 4),
    }


def append_metrics_csv(row: Dict[str, Any]) -> None:
    file_exists = os.path.exists(REQUEST_METRICS_CSV)
    fieldnames = [
        "timestamp_utc",
        "prompt_id",
        "question",
        "device_ids",
        "farm_labels",
        "response_time_sec",
        "answer_length_chars",
        "input_tokens",
        "output_tokens",
        "total_tokens",
        "relevance",
        "correctness",
        "actionability",
        "clarity",
        "advisory_quality_score",
        "accuracy_score",
        "accuracy_percent",
    ]

    with open(REQUEST_METRICS_CSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not file_exists:
            writer.writeheader()
        writer.writerow({
            "timestamp_utc": row["timestamp_utc"],
            "prompt_id": row["prompt_id"],
            "question": row["question"],
            "device_ids": json.dumps(row["device_ids"], ensure_ascii=False),
            "farm_labels": json.dumps(row["farm_labels"], ensure_ascii=False),
            "response_time_sec": row["response_time_sec"],
            "answer_length_chars": row["answer_length_chars"],
            "input_tokens": row["input_tokens"],
            "output_tokens": row["output_tokens"],
            "total_tokens": row["total_tokens"],
            "relevance": row["relevance"],
            "correctness": row["correctness"],
            "actionability": row["actionability"],
            "clarity": row["clarity"],
            "advisory_quality_score": row["advisory_quality_score"],
            "accuracy_score": row["accuracy_score"],
            "accuracy_percent": row["accuracy_percent"],
        })


def append_metrics_jsonl(row: Dict[str, Any]) -> None:
    with open(REQUEST_METRICS_JSONL, "a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def rebuild_summary_json() -> None:
    if not os.path.exists(REQUEST_METRICS_CSV):
        return

    with open(REQUEST_METRICS_CSV, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    if not rows:
        return

    response_times = [float(r["response_time_sec"]) for r in rows if r.get("response_time_sec")]
    quality_scores = [float(r["advisory_quality_score"]) for r in rows if r.get("advisory_quality_score")]
    accuracy_scores = [float(r["accuracy_score"]) for r in rows if r.get("accuracy_score")]
    input_tokens = [float(r["input_tokens"]) for r in rows if r.get("input_tokens")]
    output_tokens = [float(r["output_tokens"]) for r in rows if r.get("output_tokens")]
    total_tokens = [float(r["total_tokens"]) for r in rows if r.get("total_tokens")]

    by_prompt: Dict[str, Dict[str, Any]] = {}
    for r in rows:
        pid = r["prompt_id"]
        by_prompt.setdefault(
            pid,
            {
                "count": 0,
                "response_times": [],
                "quality_scores": [],
                "accuracy_scores": [],
                "input_tokens": [],
                "output_tokens": [],
                "total_tokens": [],
            },
        )
        by_prompt[pid]["count"] += 1
        if r.get("response_time_sec"):
            by_prompt[pid]["response_times"].append(float(r["response_time_sec"]))
        if r.get("advisory_quality_score"):
            by_prompt[pid]["quality_scores"].append(float(r["advisory_quality_score"]))
        if r.get("accuracy_score"):
            by_prompt[pid]["accuracy_scores"].append(float(r["accuracy_score"]))
        if r.get("input_tokens"):
            by_prompt[pid]["input_tokens"].append(float(r["input_tokens"]))
        if r.get("output_tokens"):
            by_prompt[pid]["output_tokens"].append(float(r["output_tokens"]))
        if r.get("total_tokens"):
            by_prompt[pid]["total_tokens"].append(float(r["total_tokens"]))

    summary = {
        "total_requests": len(rows),
        "avg_response_time_sec": round(mean(response_times), 4) if response_times else None,
        "avg_advisory_quality_score": round(mean(quality_scores), 4) if quality_scores else None,
        "avg_accuracy": round(mean(accuracy_scores), 4) if accuracy_scores else None,
        "avg_accuracy_percent": round(mean(accuracy_scores) * 100.0, 2) if accuracy_scores else None,
        "avg_input_tokens": round(mean(input_tokens), 2) if input_tokens else None,
        "avg_output_tokens": round(mean(output_tokens), 2) if output_tokens else None,
        "avg_total_tokens": round(mean(total_tokens), 2) if total_tokens else None,
        "by_prompt": {},
    }

    for pid, stats in by_prompt.items():
        rt = stats["response_times"]
        qs = stats["quality_scores"]
        acc = stats["accuracy_scores"]
        inp = stats["input_tokens"]
        out = stats["output_tokens"]
        tot = stats["total_tokens"]
        summary["by_prompt"][pid] = {
            "count": stats["count"],
            "avg_response_time_sec": round(mean(rt), 4) if rt else None,
            "avg_advisory_quality_score": round(mean(qs), 4) if qs else None,
            "avg_accuracy": round(mean(acc), 4) if acc else None,
            "avg_accuracy_percent": round(mean(acc) * 100.0, 2) if acc else None,
            "avg_input_tokens": round(mean(inp), 2) if inp else None,
            "avg_output_tokens": round(mean(out), 2) if out else None,
            "avg_total_tokens": round(mean(tot), 2) if tot else None,
        }

    with open(SUMMARY_METRICS_JSON, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)


@app.get("/farm-advice/metrics")
def get_farm_advice_metrics() -> Dict[str, Any]:
    if not os.path.exists(SUMMARY_METRICS_JSON):
        return {
            "total_requests": 0,
            "avg_response_time_sec": None,
            "avg_advisory_quality_score": None,
            "avg_accuracy": None,
            "avg_accuracy_percent": None,
            "avg_input_tokens": None,
            "avg_output_tokens": None,
            "avg_total_tokens": None,
            "by_prompt": {},
        }

    with open(SUMMARY_METRICS_JSON, "r", encoding="utf-8") as f:
        return json.load(f)


@app.post("/farm-advice/multi", response_model=MultiAdviceResponse)
async def farm_advice_multi(body: MultiAdviceRequest):
    try:
        request_start = time.perf_counter()
        timestamp_utc = datetime.utcnow().isoformat()

        context_by_farm = maybe_inject_builtin_datasets(body)

        readings_by_device_dict = {
            dev_id: [r.model_dump() for r in readings]
            for dev_id, readings in body.readings_by_device.items()
        }

        system_prompt, user_prompt = compose_farm_advisor_prompts(
            device_ids=body.device_ids,
            readings_by_device=readings_by_device_dict,
            prompt_id=body.prompt_id,
            farm_labels=body.farm_labels,
            farmer_question=body.question,
            risk_by_farm=None,
            context_by_farm=context_by_farm,
        )

        answer = await asyncio.to_thread(
            ask_farm_advisor_multi,
            body.device_ids,
            readings_by_device_dict,
            body.prompt_id,
            body.farm_labels,
            body.question,
            None,
            context_by_farm,
        )

        response_time_sec = round(time.perf_counter() - request_start, 4)

        quality = compute_advisory_quality_score(
            prompt_id=body.prompt_id,
            answer=answer,
            readings_by_device=readings_by_device_dict,
            context_by_farm=context_by_farm,
        )
        accuracy = calculate_accuracy_metrics(quality)

        input_tokens = estimate_tokens(system_prompt) + estimate_tokens(user_prompt)
        output_tokens = estimate_tokens(answer)
        total_tokens = input_tokens + output_tokens

        metrics_row = {
            "timestamp_utc": timestamp_utc,
            "prompt_id": body.prompt_id,
            "question": body.question,
            "device_ids": body.device_ids,
            "farm_labels": body.farm_labels,
            "response_time_sec": response_time_sec,
            "answer_length_chars": len(answer),
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": total_tokens,
            "relevance": quality["relevance"],
            "correctness": quality["correctness"],
            "actionability": quality["actionability"],
            "clarity": quality["clarity"],
            "advisory_quality_score": quality["overall"],
            "accuracy_score": accuracy["accuracy_score"],
            "accuracy_percent": accuracy["accuracy_percent"],
        }

        append_metrics_csv(metrics_row)
        append_metrics_jsonl({
            **metrics_row,
            "answer": answer,
            "system_prompt": system_prompt,
            "user_prompt": user_prompt,
            "context_by_farm": context_by_farm,
            "readings_by_device": readings_by_device_dict,
        })
        rebuild_summary_json()

        return JSONResponse(
            content={
                "answer": answer,
                "metrics": {
                    "response_time_sec": response_time_sec,
                    "input_tokens": input_tokens,
                    "output_tokens": output_tokens,
                    "total_tokens": total_tokens,
                    "advisory_quality_score": quality["overall"],
                    "accuracy_score": accuracy["accuracy_score"],
                    "accuracy_percent": accuracy["accuracy_percent"],
                    "subscores": {
                        "relevance": quality["relevance"],
                        "correctness": quality["correctness"],
                        "actionability": quality["actionability"],
                        "clarity": quality["clarity"],
                    },
                },
            },
            media_type="application/json; charset=utf-8"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
