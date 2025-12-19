//
//  Generated code. Do not modify.
//  source: zero_art.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Role extends $pb.ProtobufEnum {
  static const Role READ = Role._(0, _omitEnumNames ? '' : 'READ');
  static const Role WRITE = Role._(1, _omitEnumNames ? '' : 'WRITE');
  static const Role OWNERSHIP = Role._(2, _omitEnumNames ? '' : 'OWNERSHIP');
  static const Role ADMIN = Role._(3, _omitEnumNames ? '' : 'ADMIN');

  static const $core.List<Role> values = <Role> [
    READ,
    WRITE,
    OWNERSHIP,
    ADMIN,
  ];

  static final $core.Map<$core.int, Role> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Role? valueOf($core.int value) => _byValue[value];

  const Role._($core.int v, $core.String n) : super(v, n);
}

class Status extends $pb.ProtobufEnum {
  static const Status ACTIVE = Status._(0, _omitEnumNames ? '' : 'ACTIVE');
  static const Status INVITED = Status._(1, _omitEnumNames ? '' : 'INVITED');
  static const Status LEFT = Status._(2, _omitEnumNames ? '' : 'LEFT');
  static const Status PENDING_REMOVAL = Status._(3, _omitEnumNames ? '' : 'PENDING_REMOVAL');

  static const $core.List<Status> values = <Status> [
    ACTIVE,
    INVITED,
    LEFT,
    PENDING_REMOVAL,
  ];

  static final $core.Map<$core.int, Status> _byValue = $pb.ProtobufEnum.initByValue(values);
  static Status? valueOf($core.int value) => _byValue[value];

  const Status._($core.int v, $core.String n) : super(v, n);
}

class ContentAttachmentType extends $pb.ProtobufEnum {
  static const ContentAttachmentType IMAGE = ContentAttachmentType._(0, _omitEnumNames ? '' : 'IMAGE');
  static const ContentAttachmentType BINARY = ContentAttachmentType._(1, _omitEnumNames ? '' : 'BINARY');
  static const ContentAttachmentType VIDEO = ContentAttachmentType._(2, _omitEnumNames ? '' : 'VIDEO');

  static const $core.List<ContentAttachmentType> values = <ContentAttachmentType> [
    IMAGE,
    BINARY,
    VIDEO,
  ];

  static final $core.Map<$core.int, ContentAttachmentType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ContentAttachmentType? valueOf($core.int value) => _byValue[value];

  const ContentAttachmentType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
