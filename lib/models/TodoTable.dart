/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;


/** This is an auto generated class representing the TodoTable type in your schema. */
class TodoTable extends amplify_core.Model {
  static const classType = const _TodoTableModelType();
  final String id;
  final amplify_core.TemporalDateTime? _timestamp;
  final String? _device_id;
  final String? _dev_eui;
  final String? _temperature;
  final String? _moisture;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  TodoTableModelIdentifier get modelIdentifier {
      return TodoTableModelIdentifier(
        id: id
      );
  }
  
  amplify_core.TemporalDateTime? get timestamp {
    return _timestamp;
  }
  
  String? get device_id {
    return _device_id;
  }
  
  String? get dev_eui {
    return _dev_eui;
  }
  
  String? get temperature {
    return _temperature;
  }
  
  String? get moisture {
    return _moisture;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const TodoTable._internal({required this.id, timestamp, device_id, dev_eui, temperature, moisture, createdAt, updatedAt}): _timestamp = timestamp, _device_id = device_id, _dev_eui = dev_eui, _temperature = temperature, _moisture = moisture, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory TodoTable({String? id, amplify_core.TemporalDateTime? timestamp, String? device_id, String? dev_eui, String? temperature, String? moisture}) {
    return TodoTable._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      timestamp: timestamp,
      device_id: device_id,
      dev_eui: dev_eui,
      temperature: temperature,
      moisture: moisture);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TodoTable &&
      id == other.id &&
      _timestamp == other._timestamp &&
      _device_id == other._device_id &&
      _dev_eui == other._dev_eui &&
      _temperature == other._temperature &&
      _moisture == other._moisture;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("TodoTable {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("timestamp=" + (_timestamp != null ? _timestamp!.format() : "null") + ", ");
    buffer.write("device_id=" + "$_device_id" + ", ");
    buffer.write("dev_eui=" + "$_dev_eui" + ", ");
    buffer.write("temperature=" + "$_temperature" + ", ");
    buffer.write("moisture=" + "$_moisture" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  TodoTable copyWith({amplify_core.TemporalDateTime? timestamp, String? device_id, String? dev_eui, String? temperature, String? moisture}) {
    return TodoTable._internal(
      id: id,
      timestamp: timestamp ?? this.timestamp,
      device_id: device_id ?? this.device_id,
      dev_eui: dev_eui ?? this.dev_eui,
      temperature: temperature ?? this.temperature,
      moisture: moisture ?? this.moisture);
  }
  
  TodoTable copyWithModelFieldValues({
    ModelFieldValue<amplify_core.TemporalDateTime?>? timestamp,
    ModelFieldValue<String?>? device_id,
    ModelFieldValue<String?>? dev_eui,
    ModelFieldValue<String?>? temperature,
    ModelFieldValue<String?>? moisture
  }) {
    return TodoTable._internal(
      id: id,
      timestamp: timestamp == null ? this.timestamp : timestamp.value,
      device_id: device_id == null ? this.device_id : device_id.value,
      dev_eui: dev_eui == null ? this.dev_eui : dev_eui.value,
      temperature: temperature == null ? this.temperature : temperature.value,
      moisture: moisture == null ? this.moisture : moisture.value
    );
  }
  
  TodoTable.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _timestamp = json['timestamp'] != null ? amplify_core.TemporalDateTime.fromString(json['timestamp']) : null,
      _device_id = json['device_id'],
      _dev_eui = json['dev_eui'],
      _temperature = json['temperature'],
      _moisture = json['moisture'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'timestamp': _timestamp?.format(), 'device_id': _device_id, 'dev_eui': _dev_eui, 'temperature': _temperature, 'moisture': _moisture, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'timestamp': _timestamp,
    'device_id': _device_id,
    'dev_eui': _dev_eui,
    'temperature': _temperature,
    'moisture': _moisture,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<TodoTableModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<TodoTableModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final TIMESTAMP = amplify_core.QueryField(fieldName: "timestamp");
  static final DEVICE_ID = amplify_core.QueryField(fieldName: "device_id");
  static final DEV_EUI = amplify_core.QueryField(fieldName: "dev_eui");
  static final TEMPERATURE = amplify_core.QueryField(fieldName: "temperature");
  static final MOISTURE = amplify_core.QueryField(fieldName: "moisture");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "TodoTable";
    modelSchemaDefinition.pluralName = "TodoTables";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.PUBLIC,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE,
          amplify_core.ModelOperation.READ
        ])
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TodoTable.TIMESTAMP,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TodoTable.DEVICE_ID,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TodoTable.DEV_EUI,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TodoTable.TEMPERATURE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: TodoTable.MOISTURE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _TodoTableModelType extends amplify_core.ModelType<TodoTable> {
  const _TodoTableModelType();
  
  @override
  TodoTable fromJson(Map<String, dynamic> jsonData) {
    return TodoTable.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'TodoTable';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [TodoTable] in your schema.
 */
class TodoTableModelIdentifier implements amplify_core.ModelIdentifier<TodoTable> {
  final String id;

  /** Create an instance of TodoTableModelIdentifier using [id] the primary key. */
  const TodoTableModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'TodoTableModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is TodoTableModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}