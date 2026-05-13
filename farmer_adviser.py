# farmer_adviser.py
import os
from typing import List, Dict, Optional, Tuple
from openai import OpenAI, OpenAIError

MODEL_NAME = os.environ.get("FARM_ADVISOR_MODEL", "meta-llama/Meta-Llama-3-8B-Instruct")
HF_BASE_URL = os.environ.get("HF_BASE_URL", "https://router.huggingface.co/v1")

DEFAULT_TIMEOUT_SECS = float(os.environ.get("FARM_ADVISOR_TIMEOUT_SECS", "35"))
DEFAULT_MAX_RETRIES = int(os.environ.get("FARM_ADVISOR_MAX_RETRIES", "1"))
DEFAULT_MAX_TOKENS = int(os.environ.get("FARM_ADVISOR_MAX_TOKENS", "320"))
DEFAULT_TEMPERATURE = float(os.environ.get("FARM_ADVISOR_TEMPERATURE", "0.2"))

_CLIENT: Optional[OpenAI] = None


def _get_client() -> OpenAI:
    global _CLIENT
    if _CLIENT is not None:
        return _CLIENT
    token = os.environ.get("HF_TOKEN")
    if not token:
        raise RuntimeError("HF_TOKEN environment variable is not set. Run: export HF_TOKEN='hf_xxx'")
    _CLIENT = OpenAI(
        base_url=HF_BASE_URL,
        api_key=token,
        timeout=DEFAULT_TIMEOUT_SECS,
        max_retries=DEFAULT_MAX_RETRIES,
    )
    return _CLIENT


PROMPTS: Dict[str, Dict[str, str]] = {
    "IMMEDIATE_IRRIGATION": {
        "title": "Should I irrigate now?",
        "format": (
            "You are an agronomist advising a farmer who needs an immediate irrigation decision.\n"
            "Use only the data provided. Be practical, specific, and direct.\n"
            "Use Farm labels only. Never mention device IDs.\n\n"
            "Return exactly these sections:\n"
            "Irrigation decision:\n- one short paragraph with a clear yes / no / wait recommendation\n\n"
            "What is driving this decision:\n- 2 to 4 bullets tied directly to moisture and temperature trends\n\n"
            "Action to take now:\n- 2 to 3 bullets\n\n"
            "Field check right now:\n- 1 bullet"
        ),
    },
    "HEAT_STRESS_ALERT": {
        "title": "Is my crop under heat stress right now?",
        "format": (
            "You are an agronomist checking whether the crop is under current heat stress.\n"
            "Use only the data provided. Combine heat and moisture status.\n"
            "Use Farm labels only. Keep the answer practical and field-focused.\n\n"
            "Return exactly these sections:\n"
            "Heat stress assessment:\n- one short paragraph stating whether stress looks low, moderate, or high\n\n"
            "What is causing the stress signal:\n- 2 to 4 bullets tied to temperature and moisture conditions\n\n"
            "Immediate management:\n- 2 to 3 bullets\n\n"
            "What to watch over the next few hours:\n- 1 bullet"
        ),
    },
    "YIELD_IMPACT": {
        "title": "How will current conditions affect yield?",
        "format": (
            "You are an agronomist evaluating how current field conditions may influence yield.\n"
            "Use only the data and context provided. Do not overclaim or predict exact yield numbers unless given.\n"
            "Sound practical, cautious, and management-oriented.\n\n"
            "Return exactly these sections:\n"
            "Yield outlook:\n- one short paragraph describing likely direction and level of concern\n\n"
            "Main yield pressures:\n- 2 to 4 bullets explaining what is helping or hurting yield potential\n\n"
            "Management priority:\n- 2 to 3 bullets focused on what should be managed first\n\n"
            "Agronomist takeaway:\n- 1 short bullet summarizing the main message"
        ),
    },
    "CROP_RESPONSE": {
        "title": "How is my crop responding to changing conditions?",
        "format": (
            "You are an agronomist interpreting how the crop is responding to recent environmental change.\n"
            "Use only the data and context provided. Explain the pattern in simple agronomy language.\n"
            "Do not sound like a chatbot.\n\n"
            "Return exactly these sections:\n"
            "Crop response summary:\n- one short paragraph describing whether the crop appears stable, recovering, or under pressure\n\n"
            "Pattern in the field data:\n- 2 to 4 bullets explaining the trend you see\n\n"
            "What this means for management:\n- 2 to 3 bullets\n\n"
            "What to monitor next:\n- 1 bullet"
        ),
    },
    "SOIL_NUTRIENT": {
        "title": "Is soil limiting my crop performance?",
        "format": (
            "You are an agronomist reviewing whether soil conditions may be limiting crop performance.\n"
            "Use the soil profile context when available.\n"
            "Focus on pH, organic carbon, and nitrogen in plain language.\n"
            "Keep the answer practical and management-oriented.\n\n"
            "Return exactly these sections:\n"
            "Soil limitation summary:\n- one short paragraph stating whether soil is likely a weak point or not\n\n"
            "What stands out in the soil profile:\n- 2 to 4 bullets tied directly to pH, organic carbon, and nitrogen\n\n"
            "Management direction:\n- 2 to 3 bullets on what should be checked, corrected, or monitored\n\n"
            "Agronomist takeaway:\n- 1 short bullet summarizing the main soil message"
        ),
    },
}


def _farm_label(device_id: str, farm_labels: Dict[str, str]) -> str:
    return farm_labels.get(device_id, device_id)


def build_sensor_summary(device_id: str, readings: List[Dict], farm_labels: Dict[str, str]) -> str:
    label = _farm_label(device_id, farm_labels)
    if not readings:
        return f"No recent readings available for {label}."
    readings_sorted = sorted(readings, key=lambda r: r.get("timestamp", ""), reverse=True)
    lines = [f"{label} readings (latest first):"]
    for r in readings_sorted[:15]:
        t = r.get("timestamp", "unknown-time")
        temp = r.get("temperature", "NA")
        moist = r.get("moisture", "NA")
        lines.append(f"- {t}: temperature={temp}, moisture={moist}")
    return "\n".join(lines)


def build_multi_sensor_summary(device_ids: List[str], readings_by_device: Dict[str, List[Dict]], farm_labels: Dict[str, str]) -> str:
    return "\n\n".join(build_sensor_summary(device_id, readings_by_device.get(device_id, []), farm_labels) for device_id in device_ids)


def build_system_prompt(prompt_id: str) -> str:
    base = (
        "You are a practical agronomist helping with five farm views that mix live sensor farms and dataset-backed farms.\n"
        "Use only the data and context provided in the prompt.\n"
        "Use short sentences, concrete recommendations, and a calm agronomist tone.\n"
        "Never mention device IDs. Always use the Farm labels.\n"
        "Do not invent crop type, growth stage, rainfall, irrigation volume, or disease pressure.\n"
        "When data is limited, say 'based on the readings and context I have here'.\n"
        "Tie every recommendation to the observed moisture, temperature, climate, or soil pattern.\n"
    )
    spec = PROMPTS.get(prompt_id)
    if not spec:
        return base + "\nReturn a short agronomy answer with 2 to 4 practical suggestions."
    return base + "\n" + spec["format"]


def compose_farm_advisor_prompts(
    device_ids: List[str],
    readings_by_device: Dict[str, List[Dict]],
    prompt_id: str,
    farm_labels: Optional[Dict[str, str]] = None,
    farmer_question: str = "",
    risk_by_farm: Optional[Dict[str, Dict[str, float]]] = None,
    context_by_farm: Optional[Dict[str, str]] = None,
) -> Tuple[str, str]:
    farm_labels = farm_labels or {}
    sensor_text = build_multi_sensor_summary(device_ids, readings_by_device, farm_labels)
    system_prompt = build_system_prompt(prompt_id)
    prompt_title = PROMPTS.get(prompt_id, {}).get("title", "Farm advice")
    user_question = farmer_question.strip() or prompt_title

    context_text = ""
    if context_by_farm:
        blocks = []
        for dev_id in device_ids:
            label = farm_labels.get(dev_id, dev_id)
            ctx = context_by_farm.get(dev_id)
            if ctx:
                blocks.append(f"{label}: {ctx}")
        if blocks:
            context_text = "Additional farm context:\n" + "\n".join(f"- {b}" for b in blocks) + "\n\n"

    risk_text = ""
    if risk_by_farm:
        lines = []
        for dev_id in device_ids:
            label = farm_labels.get(dev_id, dev_id)
            rb = risk_by_farm.get(dev_id)
            if not rb:
                continue
            score = rb.get("risk_score", 0.0)
            lines.append(f"- {label}: risk={score:.2f}")
        if lines:
            risk_text = "Computed risk (0 to 1):\n" + "\n".join(lines) + "\n\n"

    user_prompt = (
        f"Prompt: {prompt_title}\n"
        f"{risk_text}"
        f"{context_text}"
        "Here are the recent readings for the selected farms:\n"
        "----------------------------------\n"
        f"{sensor_text}\n\n"
        "Farmer request:\n"
        f"{user_question}\n\n"
        "Use only the Farm labels. Follow the requested structure exactly."
    )
    return system_prompt, user_prompt


def ask_farm_advisor_multi(
    device_ids: List[str],
    readings_by_device: Dict[str, List[Dict]],
    prompt_id: str,
    farm_labels: Optional[Dict[str, str]] = None,
    farmer_question: str = "",
    risk_by_farm: Optional[Dict[str, Dict[str, float]]] = None,
    context_by_farm: Optional[Dict[str, str]] = None,
    max_tokens: int = DEFAULT_MAX_TOKENS,
    temperature: float = DEFAULT_TEMPERATURE,
) -> str:
    system_prompt, user_prompt = compose_farm_advisor_prompts(
        device_ids=device_ids,
        readings_by_device=readings_by_device,
        prompt_id=prompt_id,
        farm_labels=farm_labels,
        farmer_question=farmer_question,
        risk_by_farm=risk_by_farm,
        context_by_farm=context_by_farm,
    )

    try:
        client = _get_client()
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=max_tokens,
            temperature=temperature,
        )
        return response.choices[0].message.content.strip()
    except (OpenAIError, Exception) as e:
        return f"Sorry, I could not contact the farm advisor model: {e}"
