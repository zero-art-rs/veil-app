//
//  Generated code. Do not modify.
//  source: zero_art.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use roleDescriptor instead')
const Role$json = {
  '1': 'Role',
  '2': [
    {'1': 'READ', '2': 0},
    {'1': 'WRITE', '2': 1},
    {'1': 'OWNERSHIP', '2': 2},
    {'1': 'ADMIN', '2': 3},
  ],
};

/// Descriptor for `Role`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List roleDescriptor = $convert.base64Decode(
    'CgRSb2xlEggKBFJFQUQQABIJCgVXUklURRABEg0KCU9XTkVSU0hJUBACEgkKBUFETUlOEAM=');

@$core.Deprecated('Use contentAttachmentTypeDescriptor instead')
const ContentAttachmentType$json = {
  '1': 'ContentAttachmentType',
  '2': [
    {'1': 'IMAGE', '2': 0},
    {'1': 'BINARY', '2': 1},
    {'1': 'VIDEO', '2': 2},
  ],
};

/// Descriptor for `ContentAttachmentType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List contentAttachmentTypeDescriptor = $convert.base64Decode(
    'ChVDb250ZW50QXR0YWNobWVudFR5cGUSCQoFSU1BR0UQABIKCgZCSU5BUlkQARIJCgVWSURFTx'
    'AC');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'public_key', '3': 3, '4': 1, '5': 12, '10': 'publicKey'},
    {'1': 'picture', '3': 4, '4': 1, '5': 12, '10': 'picture'},
    {'1': 'role', '3': 5, '4': 1, '5': 14, '6': '.zero_art_proto.Role', '10': 'role'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnB1YmxpY19rZX'
    'kYAyABKAxSCXB1YmxpY0tleRIYCgdwaWN0dXJlGAQgASgMUgdwaWN0dXJlEigKBHJvbGUYBSAB'
    'KA4yFC56ZXJvX2FydF9wcm90by5Sb2xlUgRyb2xl');

@$core.Deprecated('Use contentAttachmentDescriptor instead')
const ContentAttachment$json = {
  '1': 'ContentAttachment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.zero_art_proto.ContentAttachmentType', '10': 'type'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `ContentAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contentAttachmentDescriptor = $convert.base64Decode(
    'ChFDb250ZW50QXR0YWNobWVudBIOCgJpZBgBIAEoCVICaWQSOQoEdHlwZRgCIAEoDjIlLnplcm'
    '9fYXJ0X3Byb3RvLkNvbnRlbnRBdHRhY2htZW50VHlwZVIEdHlwZRISCgRkYXRhGAMgASgMUgRk'
    'YXRh');

@$core.Deprecated('Use cRDTPayloadDescriptor instead')
const CRDTPayload$json = {
  '1': 'CRDTPayload',
  '2': [
    {'1': 'incremental_change', '3': 1, '4': 1, '5': 12, '9': 0, '10': 'incrementalChange'},
    {'1': 'full_document', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'fullDocument'},
    {'1': 'media_attachment', '3': 3, '4': 1, '5': 11, '6': '.zero_art_proto.ContentAttachment', '9': 0, '10': 'mediaAttachment'},
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `CRDTPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cRDTPayloadDescriptor = $convert.base64Decode(
    'CgtDUkRUUGF5bG9hZBIvChJpbmNyZW1lbnRhbF9jaGFuZ2UYASABKAxIAFIRaW5jcmVtZW50YW'
    'xDaGFuZ2USJQoNZnVsbF9kb2N1bWVudBgCIAEoDEgAUgxmdWxsRG9jdW1lbnQSTgoQbWVkaWFf'
    'YXR0YWNobWVudBgDIAEoCzIhLnplcm9fYXJ0X3Byb3RvLkNvbnRlbnRBdHRhY2htZW50SABSD2'
    '1lZGlhQXR0YWNobWVudEIJCgdwYXlsb2Fk');

@$core.Deprecated('Use chatPayloadDescriptor instead')
const ChatPayload$json = {
  '1': 'ChatPayload',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 12, '9': 0, '10': 'text'},
    {'1': 'img', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'img'},
    {'1': 'file', '3': 3, '4': 1, '5': 12, '9': 0, '10': 'file'},
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `ChatPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatPayloadDescriptor = $convert.base64Decode(
    'CgtDaGF0UGF5bG9hZBIUCgR0ZXh0GAEgASgMSABSBHRleHQSEgoDaW1nGAIgASgMSABSA2ltZx'
    'IUCgRmaWxlGAMgASgMSABSBGZpbGVCCQoHcGF5bG9hZA==');

@$core.Deprecated('Use groupInfoDescriptor instead')
const GroupInfo$json = {
  '1': 'GroupInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created', '3': 3, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'created'},
    {'1': 'picture', '3': 4, '4': 1, '5': 12, '10': 'picture'},
    {'1': 'members', '3': 10, '4': 3, '5': 11, '6': '.zero_art_proto.User', '10': 'members'},
  ],
};

/// Descriptor for `GroupInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupInfoDescriptor = $convert.base64Decode(
    'CglHcm91cEluZm8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSNAoHY3JlYX'
    'RlZBgDIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSB2NyZWF0ZWQSGAoHcGljdHVy'
    'ZRgEIAEoDFIHcGljdHVyZRIuCgdtZW1iZXJzGAogAygLMhQuemVyb19hcnRfcHJvdG8uVXNlcl'
    'IHbWVtYmVycw==');

@$core.Deprecated('Use groupActionPayloadDescriptor instead')
const GroupActionPayload$json = {
  '1': 'GroupActionPayload',
  '2': [
    {'1': 'init', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.GroupInfo', '9': 0, '10': 'init'},
    {'1': 'invite_member', '3': 2, '4': 1, '5': 11, '6': '.zero_art_proto.GroupInfo', '9': 0, '10': 'inviteMember'},
    {'1': 'remove_member', '3': 3, '4': 1, '5': 11, '6': '.zero_art_proto.User', '9': 0, '10': 'removeMember'},
    {'1': 'join_group', '3': 4, '4': 1, '5': 11, '6': '.zero_art_proto.User', '9': 0, '10': 'joinGroup'},
    {'1': 'change_user', '3': 5, '4': 1, '5': 11, '6': '.zero_art_proto.User', '9': 0, '10': 'changeUser'},
    {'1': 'change_group', '3': 6, '4': 1, '5': 11, '6': '.zero_art_proto.GroupInfo', '9': 0, '10': 'changeGroup'},
    {'1': 'leave_group', '3': 7, '4': 1, '5': 11, '6': '.zero_art_proto.User', '9': 0, '10': 'leaveGroup'},
    {'1': 'finalize_removal', '3': 8, '4': 1, '5': 11, '6': '.zero_art_proto.User', '9': 0, '10': 'finalizeRemoval'},
  ],
  '8': [
    {'1': 'action'},
  ],
};

/// Descriptor for `GroupActionPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupActionPayloadDescriptor = $convert.base64Decode(
    'ChJHcm91cEFjdGlvblBheWxvYWQSLwoEaW5pdBgBIAEoCzIZLnplcm9fYXJ0X3Byb3RvLkdyb3'
    'VwSW5mb0gAUgRpbml0EkAKDWludml0ZV9tZW1iZXIYAiABKAsyGS56ZXJvX2FydF9wcm90by5H'
    'cm91cEluZm9IAFIMaW52aXRlTWVtYmVyEjsKDXJlbW92ZV9tZW1iZXIYAyABKAsyFC56ZXJvX2'
    'FydF9wcm90by5Vc2VySABSDHJlbW92ZU1lbWJlchI1Cgpqb2luX2dyb3VwGAQgASgLMhQuemVy'
    'b19hcnRfcHJvdG8uVXNlckgAUglqb2luR3JvdXASNwoLY2hhbmdlX3VzZXIYBSABKAsyFC56ZX'
    'JvX2FydF9wcm90by5Vc2VySABSCmNoYW5nZVVzZXISPgoMY2hhbmdlX2dyb3VwGAYgASgLMhku'
    'emVyb19hcnRfcHJvdG8uR3JvdXBJbmZvSABSC2NoYW5nZUdyb3VwEjcKC2xlYXZlX2dyb3VwGA'
    'cgASgLMhQuemVyb19hcnRfcHJvdG8uVXNlckgAUgpsZWF2ZUdyb3VwEkEKEGZpbmFsaXplX3Jl'
    'bW92YWwYCCABKAsyFC56ZXJvX2FydF9wcm90by5Vc2VySABSD2ZpbmFsaXplUmVtb3ZhbEIICg'
    'ZhY3Rpb24=');

@$core.Deprecated('Use payloadDescriptor instead')
const Payload$json = {
  '1': 'Payload',
  '2': [
    {'1': 'crdt', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.CRDTPayload', '9': 0, '10': 'crdt'},
    {'1': 'chat', '3': 2, '4': 1, '5': 11, '6': '.zero_art_proto.ChatPayload', '9': 0, '10': 'chat'},
    {'1': 'action', '3': 10, '4': 1, '5': 11, '6': '.zero_art_proto.GroupActionPayload', '9': 0, '10': 'action'},
  ],
  '8': [
    {'1': 'content'},
  ],
};

/// Descriptor for `Payload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List payloadDescriptor = $convert.base64Decode(
    'CgdQYXlsb2FkEjEKBGNyZHQYASABKAsyGy56ZXJvX2FydF9wcm90by5DUkRUUGF5bG9hZEgAUg'
    'RjcmR0EjEKBGNoYXQYAiABKAsyGy56ZXJvX2FydF9wcm90by5DaGF0UGF5bG9hZEgAUgRjaGF0'
    'EjwKBmFjdGlvbhgKIAEoCzIiLnplcm9fYXJ0X3Byb3RvLkdyb3VwQWN0aW9uUGF5bG9hZEgAUg'
    'ZhY3Rpb25CCQoHY29udGVudA==');

@$core.Deprecated('Use groupOperationDescriptor instead')
const GroupOperation$json = {
  '1': 'GroupOperation',
  '2': [
    {'1': 'init', '3': 1, '4': 1, '5': 12, '9': 0, '10': 'init'},
    {'1': 'add_member', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'addMember'},
    {'1': 'remove_member', '3': 3, '4': 1, '5': 12, '9': 0, '10': 'removeMember'},
    {'1': 'key_update', '3': 4, '4': 1, '5': 12, '9': 0, '10': 'keyUpdate'},
    {'1': 'leave_group', '3': 5, '4': 1, '5': 12, '9': 0, '10': 'leaveGroup'},
    {'1': 'drop_group', '3': 10, '4': 1, '5': 12, '9': 0, '10': 'dropGroup'},
  ],
  '8': [
    {'1': 'operation'},
  ],
};

/// Descriptor for `GroupOperation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupOperationDescriptor = $convert.base64Decode(
    'Cg5Hcm91cE9wZXJhdGlvbhIUCgRpbml0GAEgASgMSABSBGluaXQSHwoKYWRkX21lbWJlchgCIA'
    'EoDEgAUglhZGRNZW1iZXISJQoNcmVtb3ZlX21lbWJlchgDIAEoDEgAUgxyZW1vdmVNZW1iZXIS'
    'HwoKa2V5X3VwZGF0ZRgEIAEoDEgAUglrZXlVcGRhdGUSIQoLbGVhdmVfZ3JvdXAYBSABKAxIAF'
    'IKbGVhdmVHcm91cBIfCgpkcm9wX2dyb3VwGAogASgMSABSCWRyb3BHcm91cEILCglvcGVyYXRp'
    'b24=');

@$core.Deprecated('Use frameTBSDescriptor instead')
const FrameTBS$json = {
  '1': 'FrameTBS',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'epoch', '3': 2, '4': 1, '5': 4, '10': 'epoch'},
    {'1': 'nonce', '3': 3, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'group_operation', '3': 5, '4': 1, '5': 11, '6': '.zero_art_proto.GroupOperation', '10': 'groupOperation'},
    {'1': 'protected_payload', '3': 6, '4': 1, '5': 12, '10': 'protectedPayload'},
  ],
};

/// Descriptor for `FrameTBS`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameTBSDescriptor = $convert.base64Decode(
    'CghGcmFtZVRCUxIZCghncm91cF9pZBgBIAEoCVIHZ3JvdXBJZBIUCgVlcG9jaBgCIAEoBFIFZX'
    'BvY2gSFAoFbm9uY2UYAyABKAxSBW5vbmNlEkcKD2dyb3VwX29wZXJhdGlvbhgFIAEoCzIeLnpl'
    'cm9fYXJ0X3Byb3RvLkdyb3VwT3BlcmF0aW9uUg5ncm91cE9wZXJhdGlvbhIrChFwcm90ZWN0ZW'
    'RfcGF5bG9hZBgGIAEoDFIQcHJvdGVjdGVkUGF5bG9hZA==');

@$core.Deprecated('Use frameDescriptor instead')
const Frame$json = {
  '1': 'Frame',
  '2': [
    {'1': 'frame', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.FrameTBS', '10': 'frame'},
    {'1': 'proof', '3': 9, '4': 1, '5': 12, '10': 'proof'},
  ],
};

/// Descriptor for `Frame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List frameDescriptor = $convert.base64Decode(
    'CgVGcmFtZRIuCgVmcmFtZRgBIAEoCzIYLnplcm9fYXJ0X3Byb3RvLkZyYW1lVEJTUgVmcmFtZR'
    'IUCgVwcm9vZhgJIAEoDFIFcHJvb2Y=');

@$core.Deprecated('Use sPFrameDescriptor instead')
const SPFrame$json = {
  '1': 'SPFrame',
  '2': [
    {'1': 'seq_num', '3': 1, '4': 1, '5': 4, '10': 'seqNum'},
    {'1': 'created', '3': 4, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'created'},
    {'1': 'frame', '3': 5, '4': 1, '5': 11, '6': '.zero_art_proto.Frame', '10': 'frame'},
  ],
};

/// Descriptor for `SPFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sPFrameDescriptor = $convert.base64Decode(
    'CgdTUEZyYW1lEhcKB3NlcV9udW0YASABKARSBnNlcU51bRI0CgdjcmVhdGVkGAQgASgLMhouZ2'
    '9vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIHY3JlYXRlZBIrCgVmcmFtZRgFIAEoCzIVLnplcm9f'
    'YXJ0X3Byb3RvLkZyYW1lUgVmcmFtZQ==');

@$core.Deprecated('Use sPFramesDescriptor instead')
const SPFrames$json = {
  '1': 'SPFrames',
  '2': [
    {'1': 'sp_frames', '3': 1, '4': 3, '5': 11, '6': '.zero_art_proto.SPFrame', '10': 'spFrames'},
  ],
};

/// Descriptor for `SPFrames`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sPFramesDescriptor = $convert.base64Decode(
    'CghTUEZyYW1lcxI0CglzcF9mcmFtZXMYASADKAsyFy56ZXJvX2FydF9wcm90by5TUEZyYW1lUg'
    'hzcEZyYW1lcw==');

@$core.Deprecated('Use protectedPayloadTBSDescriptor instead')
const ProtectedPayloadTBS$json = {
  '1': 'ProtectedPayloadTBS',
  '2': [
    {'1': 'seq_num', '3': 1, '4': 1, '5': 4, '10': 'seqNum'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'userId'},
    {'1': 'leaf_id', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'leafId'},
    {'1': 'created', '3': 4, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'created'},
    {'1': 'payload', '3': 5, '4': 3, '5': 11, '6': '.zero_art_proto.Payload', '10': 'payload'},
  ],
  '8': [
    {'1': 'sender'},
  ],
};

/// Descriptor for `ProtectedPayloadTBS`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protectedPayloadTBSDescriptor = $convert.base64Decode(
    'ChNQcm90ZWN0ZWRQYXlsb2FkVEJTEhcKB3NlcV9udW0YASABKARSBnNlcU51bRIZCgd1c2VyX2'
    'lkGAIgASgJSABSBnVzZXJJZBIZCgdsZWFmX2lkGAMgASgJSABSBmxlYWZJZBI0CgdjcmVhdGVk'
    'GAQgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIHY3JlYXRlZBIxCgdwYXlsb2FkGA'
    'UgAygLMhcuemVyb19hcnRfcHJvdG8uUGF5bG9hZFIHcGF5bG9hZEIICgZzZW5kZXI=');

@$core.Deprecated('Use protectedPayloadDescriptor instead')
const ProtectedPayload$json = {
  '1': 'ProtectedPayload',
  '2': [
    {'1': 'payload', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.ProtectedPayloadTBS', '10': 'payload'},
    {'1': 'signature', '3': 9, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `ProtectedPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protectedPayloadDescriptor = $convert.base64Decode(
    'ChBQcm90ZWN0ZWRQYXlsb2FkEj0KB3BheWxvYWQYASABKAsyIy56ZXJvX2FydF9wcm90by5Qcm'
    '90ZWN0ZWRQYXlsb2FkVEJTUgdwYXlsb2FkEhwKCXNpZ25hdHVyZRgJIAEoDFIJc2lnbmF0dXJl');

@$core.Deprecated('Use protectedInviteDataDescriptor instead')
const ProtectedInviteData$json = {
  '1': 'ProtectedInviteData',
  '2': [
    {'1': 'epoch', '3': 2, '4': 1, '5': 4, '10': 'epoch'},
    {'1': 'stage_key', '3': 3, '4': 1, '5': 12, '10': 'stageKey'},
    {'1': 'group_info', '3': 4, '4': 1, '5': 11, '6': '.zero_art_proto.GroupInfo', '10': 'groupInfo'},
  ],
};

/// Descriptor for `ProtectedInviteData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protectedInviteDataDescriptor = $convert.base64Decode(
    'ChNQcm90ZWN0ZWRJbnZpdGVEYXRhEhQKBWVwb2NoGAIgASgEUgVlcG9jaBIbCglzdGFnZV9rZX'
    'kYAyABKAxSCHN0YWdlS2V5EjgKCmdyb3VwX2luZm8YBCABKAsyGS56ZXJvX2FydF9wcm90by5H'
    'cm91cEluZm9SCWdyb3VwSW5mbw==');

@$core.Deprecated('Use identifiedInviteDescriptor instead')
const IdentifiedInvite$json = {
  '1': 'IdentifiedInvite',
  '2': [
    {'1': 'identity_public_key', '3': 1, '4': 1, '5': 12, '10': 'identityPublicKey'},
    {'1': 'spk_public_key', '3': 2, '4': 1, '5': 12, '10': 'spkPublicKey'},
  ],
};

/// Descriptor for `IdentifiedInvite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List identifiedInviteDescriptor = $convert.base64Decode(
    'ChBJZGVudGlmaWVkSW52aXRlEi4KE2lkZW50aXR5X3B1YmxpY19rZXkYASABKAxSEWlkZW50aX'
    'R5UHVibGljS2V5EiQKDnNwa19wdWJsaWNfa2V5GAIgASgMUgxzcGtQdWJsaWNLZXk=');

@$core.Deprecated('Use unidentifiedInviteDescriptor instead')
const UnidentifiedInvite$json = {
  '1': 'UnidentifiedInvite',
  '2': [
    {'1': 'private_key', '3': 3, '4': 1, '5': 12, '10': 'privateKey'},
  ],
};

/// Descriptor for `UnidentifiedInvite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unidentifiedInviteDescriptor = $convert.base64Decode(
    'ChJVbmlkZW50aWZpZWRJbnZpdGUSHwoLcHJpdmF0ZV9rZXkYAyABKAxSCnByaXZhdGVLZXk=');

@$core.Deprecated('Use inviteTbsDescriptor instead')
const InviteTbs$json = {
  '1': 'InviteTbs',
  '2': [
    {'1': 'identified_invite', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.IdentifiedInvite', '9': 0, '10': 'identifiedInvite'},
    {'1': 'unidentified_invite', '3': 2, '4': 1, '5': 11, '6': '.zero_art_proto.UnidentifiedInvite', '9': 0, '10': 'unidentifiedInvite'},
    {'1': 'protected_invite_data', '3': 9, '4': 1, '5': 12, '10': 'protectedInviteData'},
    {'1': 'identity_public_key', '3': 10, '4': 1, '5': 12, '10': 'identityPublicKey'},
    {'1': 'ephemeral_public_key', '3': 11, '4': 1, '5': 12, '10': 'ephemeralPublicKey'},
  ],
  '8': [
    {'1': 'invite'},
  ],
};

/// Descriptor for `InviteTbs`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inviteTbsDescriptor = $convert.base64Decode(
    'CglJbnZpdGVUYnMSTwoRaWRlbnRpZmllZF9pbnZpdGUYASABKAsyIC56ZXJvX2FydF9wcm90by'
    '5JZGVudGlmaWVkSW52aXRlSABSEGlkZW50aWZpZWRJbnZpdGUSVQoTdW5pZGVudGlmaWVkX2lu'
    'dml0ZRgCIAEoCzIiLnplcm9fYXJ0X3Byb3RvLlVuaWRlbnRpZmllZEludml0ZUgAUhJ1bmlkZW'
    '50aWZpZWRJbnZpdGUSMgoVcHJvdGVjdGVkX2ludml0ZV9kYXRhGAkgASgMUhNwcm90ZWN0ZWRJ'
    'bnZpdGVEYXRhEi4KE2lkZW50aXR5X3B1YmxpY19rZXkYCiABKAxSEWlkZW50aXR5UHVibGljS2'
    'V5EjAKFGVwaGVtZXJhbF9wdWJsaWNfa2V5GAsgASgMUhJlcGhlbWVyYWxQdWJsaWNLZXlCCAoG'
    'aW52aXRl');

@$core.Deprecated('Use inviteDescriptor instead')
const Invite$json = {
  '1': 'Invite',
  '2': [
    {'1': 'invite', '3': 1, '4': 1, '5': 11, '6': '.zero_art_proto.InviteTbs', '10': 'invite'},
    {'1': 'signature', '3': 9, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `Invite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inviteDescriptor = $convert.base64Decode(
    'CgZJbnZpdGUSMQoGaW52aXRlGAEgASgLMhkuemVyb19hcnRfcHJvdG8uSW52aXRlVGJzUgZpbn'
    'ZpdGUSHAoJc2lnbmF0dXJlGAkgASgMUglzaWduYXR1cmU=');

