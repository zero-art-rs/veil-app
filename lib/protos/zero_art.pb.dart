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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $0;
import 'zero_art.pbenum.dart';

export 'zero_art.pbenum.dart';

/// User definition
class User extends $pb.GeneratedMessage {
  factory User({
    $core.String? id,
    $core.String? name,
    $core.List<$core.int>? publicKey,
    $core.List<$core.int>? picture,
    Role? role,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (name != null) {
      $result.name = name;
    }
    if (publicKey != null) {
      $result.publicKey = publicKey;
    }
    if (picture != null) {
      $result.picture = picture;
    }
    if (role != null) {
      $result.role = role;
    }
    return $result;
  }
  User._() : super();
  factory User.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory User.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'User', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'publicKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'picture', $pb.PbFieldType.OY)
    ..e<Role>(5, _omitFieldNames ? '' : 'role', $pb.PbFieldType.OE, defaultOrMaker: Role.READ, valueOf: Role.valueOf, enumValues: Role.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  User clone() => User()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  User copyWith(void Function(User) updates) => super.copyWith((message) => updates(message as User)) as User;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  User createEmptyInstance() => create();
  static $pb.PbList<User> createRepeated() => $pb.PbList<User>();
  @$core.pragma('dart2js:noInline')
  static User getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get publicKey => $_getN(2);
  @$pb.TagNumber(3)
  set publicKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPublicKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublicKey() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get picture => $_getN(3);
  @$pb.TagNumber(4)
  set picture($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPicture() => $_has(3);
  @$pb.TagNumber(4)
  void clearPicture() => clearField(4);

  @$pb.TagNumber(5)
  Role get role => $_getN(4);
  @$pb.TagNumber(5)
  set role(Role v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearRole() => clearField(5);
}

class ContentAttachment extends $pb.GeneratedMessage {
  factory ContentAttachment({
    $core.String? id,
    ContentAttachmentType? type,
    $core.List<$core.int>? data,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (type != null) {
      $result.type = type;
    }
    if (data != null) {
      $result.data = data;
    }
    return $result;
  }
  ContentAttachment._() : super();
  factory ContentAttachment.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ContentAttachment.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ContentAttachment', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..e<ContentAttachmentType>(2, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE, defaultOrMaker: ContentAttachmentType.IMAGE, valueOf: ContentAttachmentType.valueOf, enumValues: ContentAttachmentType.values)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ContentAttachment clone() => ContentAttachment()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ContentAttachment copyWith(void Function(ContentAttachment) updates) => super.copyWith((message) => updates(message as ContentAttachment)) as ContentAttachment;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContentAttachment create() => ContentAttachment._();
  ContentAttachment createEmptyInstance() => create();
  static $pb.PbList<ContentAttachment> createRepeated() => $pb.PbList<ContentAttachment>();
  @$core.pragma('dart2js:noInline')
  static ContentAttachment getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContentAttachment>(create);
  static ContentAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  ContentAttachmentType get type => $_getN(1);
  @$pb.TagNumber(2)
  set type(ContentAttachmentType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => clearField(3);
}

enum CRDTPayload_Payload {
  incrementalChange, 
  fullDocument, 
  mediaAttachment, 
  notSet
}

/// CRDT payload: could be either incremental change or full document
class CRDTPayload extends $pb.GeneratedMessage {
  factory CRDTPayload({
    $core.List<$core.int>? incrementalChange,
    $core.List<$core.int>? fullDocument,
    ContentAttachment? mediaAttachment,
  }) {
    final $result = create();
    if (incrementalChange != null) {
      $result.incrementalChange = incrementalChange;
    }
    if (fullDocument != null) {
      $result.fullDocument = fullDocument;
    }
    if (mediaAttachment != null) {
      $result.mediaAttachment = mediaAttachment;
    }
    return $result;
  }
  CRDTPayload._() : super();
  factory CRDTPayload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CRDTPayload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, CRDTPayload_Payload> _CRDTPayload_PayloadByTag = {
    1 : CRDTPayload_Payload.incrementalChange,
    2 : CRDTPayload_Payload.fullDocument,
    3 : CRDTPayload_Payload.mediaAttachment,
    0 : CRDTPayload_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CRDTPayload', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'incrementalChange', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'fullDocument', $pb.PbFieldType.OY)
    ..aOM<ContentAttachment>(3, _omitFieldNames ? '' : 'mediaAttachment', subBuilder: ContentAttachment.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CRDTPayload clone() => CRDTPayload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CRDTPayload copyWith(void Function(CRDTPayload) updates) => super.copyWith((message) => updates(message as CRDTPayload)) as CRDTPayload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CRDTPayload create() => CRDTPayload._();
  CRDTPayload createEmptyInstance() => create();
  static $pb.PbList<CRDTPayload> createRepeated() => $pb.PbList<CRDTPayload>();
  @$core.pragma('dart2js:noInline')
  static CRDTPayload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CRDTPayload>(create);
  static CRDTPayload? _defaultInstance;

  CRDTPayload_Payload whichPayload() => _CRDTPayload_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get incrementalChange => $_getN(0);
  @$pb.TagNumber(1)
  set incrementalChange($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIncrementalChange() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncrementalChange() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get fullDocument => $_getN(1);
  @$pb.TagNumber(2)
  set fullDocument($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFullDocument() => $_has(1);
  @$pb.TagNumber(2)
  void clearFullDocument() => clearField(2);

  @$pb.TagNumber(3)
  ContentAttachment get mediaAttachment => $_getN(2);
  @$pb.TagNumber(3)
  set mediaAttachment(ContentAttachment v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasMediaAttachment() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaAttachment() => clearField(3);
  @$pb.TagNumber(3)
  ContentAttachment ensureMediaAttachment() => $_ensure(2);
}

enum ChatPayload_Payload {
  text, 
  img, 
  file, 
  notSet
}

/// Ordinary chat payload: text, image or file
class ChatPayload extends $pb.GeneratedMessage {
  factory ChatPayload({
    $core.List<$core.int>? text,
    $core.List<$core.int>? img,
    $core.List<$core.int>? file,
  }) {
    final $result = create();
    if (text != null) {
      $result.text = text;
    }
    if (img != null) {
      $result.img = img;
    }
    if (file != null) {
      $result.file = file;
    }
    return $result;
  }
  ChatPayload._() : super();
  factory ChatPayload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ChatPayload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, ChatPayload_Payload> _ChatPayload_PayloadByTag = {
    1 : ChatPayload_Payload.text,
    2 : ChatPayload_Payload.img,
    3 : ChatPayload_Payload.file,
    0 : ChatPayload_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ChatPayload', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'text', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'img', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'file', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ChatPayload clone() => ChatPayload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ChatPayload copyWith(void Function(ChatPayload) updates) => super.copyWith((message) => updates(message as ChatPayload)) as ChatPayload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatPayload create() => ChatPayload._();
  ChatPayload createEmptyInstance() => create();
  static $pb.PbList<ChatPayload> createRepeated() => $pb.PbList<ChatPayload>();
  @$core.pragma('dart2js:noInline')
  static ChatPayload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatPayload>(create);
  static ChatPayload? _defaultInstance;

  ChatPayload_Payload whichPayload() => _ChatPayload_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get text => $_getN(0);
  @$pb.TagNumber(1)
  set text($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get img => $_getN(1);
  @$pb.TagNumber(2)
  set img($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasImg() => $_has(1);
  @$pb.TagNumber(2)
  void clearImg() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get file => $_getN(2);
  @$pb.TagNumber(3)
  set file($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFile() => $_has(2);
  @$pb.TagNumber(3)
  void clearFile() => clearField(3);
}

class GroupInfo extends $pb.GeneratedMessage {
  factory GroupInfo({
    $core.String? id,
    $core.String? name,
    $0.Timestamp? created,
    $core.List<$core.int>? picture,
    $core.Iterable<User>? members,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (name != null) {
      $result.name = name;
    }
    if (created != null) {
      $result.created = created;
    }
    if (picture != null) {
      $result.picture = picture;
    }
    if (members != null) {
      $result.members.addAll(members);
    }
    return $result;
  }
  GroupInfo._() : super();
  factory GroupInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GroupInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GroupInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOM<$0.Timestamp>(3, _omitFieldNames ? '' : 'created', subBuilder: $0.Timestamp.create)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'picture', $pb.PbFieldType.OY)
    ..pc<User>(10, _omitFieldNames ? '' : 'members', $pb.PbFieldType.PM, subBuilder: User.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GroupInfo clone() => GroupInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GroupInfo copyWith(void Function(GroupInfo) updates) => super.copyWith((message) => updates(message as GroupInfo)) as GroupInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupInfo create() => GroupInfo._();
  GroupInfo createEmptyInstance() => create();
  static $pb.PbList<GroupInfo> createRepeated() => $pb.PbList<GroupInfo>();
  @$core.pragma('dart2js:noInline')
  static GroupInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GroupInfo>(create);
  static GroupInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $0.Timestamp get created => $_getN(2);
  @$pb.TagNumber(3)
  set created($0.Timestamp v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasCreated() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreated() => clearField(3);
  @$pb.TagNumber(3)
  $0.Timestamp ensureCreated() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.List<$core.int> get picture => $_getN(3);
  @$pb.TagNumber(4)
  set picture($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPicture() => $_has(3);
  @$pb.TagNumber(4)
  void clearPicture() => clearField(4);

  @$pb.TagNumber(10)
  $core.List<User> get members => $_getList(4);
}

enum GroupActionPayload_Action {
  init, 
  inviteMember, 
  removeMember, 
  joinGroup, 
  changeUser, 
  changeGroup, 
  leaveGroup, 
  finalizeRemoval, 
  notSet
}

/// Protected (could be visible only inside group) group actions
class GroupActionPayload extends $pb.GeneratedMessage {
  factory GroupActionPayload({
    GroupInfo? init,
    GroupInfo? inviteMember,
    User? removeMember,
    User? joinGroup,
    User? changeUser,
    GroupInfo? changeGroup,
    User? leaveGroup,
    User? finalizeRemoval,
  }) {
    final $result = create();
    if (init != null) {
      $result.init = init;
    }
    if (inviteMember != null) {
      $result.inviteMember = inviteMember;
    }
    if (removeMember != null) {
      $result.removeMember = removeMember;
    }
    if (joinGroup != null) {
      $result.joinGroup = joinGroup;
    }
    if (changeUser != null) {
      $result.changeUser = changeUser;
    }
    if (changeGroup != null) {
      $result.changeGroup = changeGroup;
    }
    if (leaveGroup != null) {
      $result.leaveGroup = leaveGroup;
    }
    if (finalizeRemoval != null) {
      $result.finalizeRemoval = finalizeRemoval;
    }
    return $result;
  }
  GroupActionPayload._() : super();
  factory GroupActionPayload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GroupActionPayload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, GroupActionPayload_Action> _GroupActionPayload_ActionByTag = {
    1 : GroupActionPayload_Action.init,
    2 : GroupActionPayload_Action.inviteMember,
    3 : GroupActionPayload_Action.removeMember,
    4 : GroupActionPayload_Action.joinGroup,
    5 : GroupActionPayload_Action.changeUser,
    6 : GroupActionPayload_Action.changeGroup,
    7 : GroupActionPayload_Action.leaveGroup,
    8 : GroupActionPayload_Action.finalizeRemoval,
    0 : GroupActionPayload_Action.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GroupActionPayload', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
    ..aOM<GroupInfo>(1, _omitFieldNames ? '' : 'init', subBuilder: GroupInfo.create)
    ..aOM<GroupInfo>(2, _omitFieldNames ? '' : 'inviteMember', subBuilder: GroupInfo.create)
    ..aOM<User>(3, _omitFieldNames ? '' : 'removeMember', subBuilder: User.create)
    ..aOM<User>(4, _omitFieldNames ? '' : 'joinGroup', subBuilder: User.create)
    ..aOM<User>(5, _omitFieldNames ? '' : 'changeUser', subBuilder: User.create)
    ..aOM<GroupInfo>(6, _omitFieldNames ? '' : 'changeGroup', subBuilder: GroupInfo.create)
    ..aOM<User>(7, _omitFieldNames ? '' : 'leaveGroup', subBuilder: User.create)
    ..aOM<User>(8, _omitFieldNames ? '' : 'finalizeRemoval', subBuilder: User.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GroupActionPayload clone() => GroupActionPayload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GroupActionPayload copyWith(void Function(GroupActionPayload) updates) => super.copyWith((message) => updates(message as GroupActionPayload)) as GroupActionPayload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupActionPayload create() => GroupActionPayload._();
  GroupActionPayload createEmptyInstance() => create();
  static $pb.PbList<GroupActionPayload> createRepeated() => $pb.PbList<GroupActionPayload>();
  @$core.pragma('dart2js:noInline')
  static GroupActionPayload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GroupActionPayload>(create);
  static GroupActionPayload? _defaultInstance;

  GroupActionPayload_Action whichAction() => _GroupActionPayload_ActionByTag[$_whichOneof(0)]!;
  void clearAction() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  GroupInfo get init => $_getN(0);
  @$pb.TagNumber(1)
  set init(GroupInfo v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasInit() => $_has(0);
  @$pb.TagNumber(1)
  void clearInit() => clearField(1);
  @$pb.TagNumber(1)
  GroupInfo ensureInit() => $_ensure(0);

  @$pb.TagNumber(2)
  GroupInfo get inviteMember => $_getN(1);
  @$pb.TagNumber(2)
  set inviteMember(GroupInfo v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasInviteMember() => $_has(1);
  @$pb.TagNumber(2)
  void clearInviteMember() => clearField(2);
  @$pb.TagNumber(2)
  GroupInfo ensureInviteMember() => $_ensure(1);

  @$pb.TagNumber(3)
  User get removeMember => $_getN(2);
  @$pb.TagNumber(3)
  set removeMember(User v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasRemoveMember() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoveMember() => clearField(3);
  @$pb.TagNumber(3)
  User ensureRemoveMember() => $_ensure(2);

  @$pb.TagNumber(4)
  User get joinGroup => $_getN(3);
  @$pb.TagNumber(4)
  set joinGroup(User v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasJoinGroup() => $_has(3);
  @$pb.TagNumber(4)
  void clearJoinGroup() => clearField(4);
  @$pb.TagNumber(4)
  User ensureJoinGroup() => $_ensure(3);

  @$pb.TagNumber(5)
  User get changeUser => $_getN(4);
  @$pb.TagNumber(5)
  set changeUser(User v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasChangeUser() => $_has(4);
  @$pb.TagNumber(5)
  void clearChangeUser() => clearField(5);
  @$pb.TagNumber(5)
  User ensureChangeUser() => $_ensure(4);

  @$pb.TagNumber(6)
  GroupInfo get changeGroup => $_getN(5);
  @$pb.TagNumber(6)
  set changeGroup(GroupInfo v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasChangeGroup() => $_has(5);
  @$pb.TagNumber(6)
  void clearChangeGroup() => clearField(6);
  @$pb.TagNumber(6)
  GroupInfo ensureChangeGroup() => $_ensure(5);

  @$pb.TagNumber(7)
  User get leaveGroup => $_getN(6);
  @$pb.TagNumber(7)
  set leaveGroup(User v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasLeaveGroup() => $_has(6);
  @$pb.TagNumber(7)
  void clearLeaveGroup() => clearField(7);
  @$pb.TagNumber(7)
  User ensureLeaveGroup() => $_ensure(6);

  @$pb.TagNumber(8)
  User get finalizeRemoval => $_getN(7);
  @$pb.TagNumber(8)
  set finalizeRemoval(User v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasFinalizeRemoval() => $_has(7);
  @$pb.TagNumber(8)
  void clearFinalizeRemoval() => clearField(8);
  @$pb.TagNumber(8)
  User ensureFinalizeRemoval() => $_ensure(7);
}

enum Payload_Content {
  crdt, 
  chat, 
  action, 
  notSet
}

/// Payload wrapper
class Payload extends $pb.GeneratedMessage {
  factory Payload({
    CRDTPayload? crdt,
    ChatPayload? chat,
    GroupActionPayload? action,
  }) {
    final $result = create();
    if (crdt != null) {
      $result.crdt = crdt;
    }
    if (chat != null) {
      $result.chat = chat;
    }
    if (action != null) {
      $result.action = action;
    }
    return $result;
  }
  Payload._() : super();
  factory Payload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Payload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, Payload_Content> _Payload_ContentByTag = {
    1 : Payload_Content.crdt,
    2 : Payload_Content.chat,
    10 : Payload_Content.action,
    0 : Payload_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Payload', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2, 10])
    ..aOM<CRDTPayload>(1, _omitFieldNames ? '' : 'crdt', subBuilder: CRDTPayload.create)
    ..aOM<ChatPayload>(2, _omitFieldNames ? '' : 'chat', subBuilder: ChatPayload.create)
    ..aOM<GroupActionPayload>(10, _omitFieldNames ? '' : 'action', subBuilder: GroupActionPayload.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Payload clone() => Payload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Payload copyWith(void Function(Payload) updates) => super.copyWith((message) => updates(message as Payload)) as Payload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Payload create() => Payload._();
  Payload createEmptyInstance() => create();
  static $pb.PbList<Payload> createRepeated() => $pb.PbList<Payload>();
  @$core.pragma('dart2js:noInline')
  static Payload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Payload>(create);
  static Payload? _defaultInstance;

  Payload_Content whichContent() => _Payload_ContentByTag[$_whichOneof(0)]!;
  void clearContent() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  CRDTPayload get crdt => $_getN(0);
  @$pb.TagNumber(1)
  set crdt(CRDTPayload v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasCrdt() => $_has(0);
  @$pb.TagNumber(1)
  void clearCrdt() => clearField(1);
  @$pb.TagNumber(1)
  CRDTPayload ensureCrdt() => $_ensure(0);

  @$pb.TagNumber(2)
  ChatPayload get chat => $_getN(1);
  @$pb.TagNumber(2)
  set chat(ChatPayload v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasChat() => $_has(1);
  @$pb.TagNumber(2)
  void clearChat() => clearField(2);
  @$pb.TagNumber(2)
  ChatPayload ensureChat() => $_ensure(1);

  /// TODO: consider adding new payload types: message, media file, etc
  @$pb.TagNumber(10)
  GroupActionPayload get action => $_getN(2);
  @$pb.TagNumber(10)
  set action(GroupActionPayload v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasAction() => $_has(2);
  @$pb.TagNumber(10)
  void clearAction() => clearField(10);
  @$pb.TagNumber(10)
  GroupActionPayload ensureAction() => $_ensure(2);
}

enum GroupOperation_Operation {
  init, 
  addMember, 
  removeMember, 
  keyUpdate, 
  leaveGroup, 
  dropGroup, 
  notSet
}

/// High level group operation visible by SP
class GroupOperation extends $pb.GeneratedMessage {
  factory GroupOperation({
    $core.List<$core.int>? init,
    $core.List<$core.int>? addMember,
    $core.List<$core.int>? removeMember,
    $core.List<$core.int>? keyUpdate,
    $core.List<$core.int>? leaveGroup,
    $core.List<$core.int>? dropGroup,
  }) {
    final $result = create();
    if (init != null) {
      $result.init = init;
    }
    if (addMember != null) {
      $result.addMember = addMember;
    }
    if (removeMember != null) {
      $result.removeMember = removeMember;
    }
    if (keyUpdate != null) {
      $result.keyUpdate = keyUpdate;
    }
    if (leaveGroup != null) {
      $result.leaveGroup = leaveGroup;
    }
    if (dropGroup != null) {
      $result.dropGroup = dropGroup;
    }
    return $result;
  }
  GroupOperation._() : super();
  factory GroupOperation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GroupOperation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, GroupOperation_Operation> _GroupOperation_OperationByTag = {
    1 : GroupOperation_Operation.init,
    2 : GroupOperation_Operation.addMember,
    3 : GroupOperation_Operation.removeMember,
    4 : GroupOperation_Operation.keyUpdate,
    5 : GroupOperation_Operation.leaveGroup,
    10 : GroupOperation_Operation.dropGroup,
    0 : GroupOperation_Operation.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GroupOperation', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 10])
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'init', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'addMember', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'removeMember', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'keyUpdate', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(5, _omitFieldNames ? '' : 'leaveGroup', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(10, _omitFieldNames ? '' : 'dropGroup', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GroupOperation clone() => GroupOperation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GroupOperation copyWith(void Function(GroupOperation) updates) => super.copyWith((message) => updates(message as GroupOperation)) as GroupOperation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupOperation create() => GroupOperation._();
  GroupOperation createEmptyInstance() => create();
  static $pb.PbList<GroupOperation> createRepeated() => $pb.PbList<GroupOperation>();
  @$core.pragma('dart2js:noInline')
  static GroupOperation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GroupOperation>(create);
  static GroupOperation? _defaultInstance;

  GroupOperation_Operation whichOperation() => _GroupOperation_OperationByTag[$_whichOneof(0)]!;
  void clearOperation() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get init => $_getN(0);
  @$pb.TagNumber(1)
  set init($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInit() => $_has(0);
  @$pb.TagNumber(1)
  void clearInit() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get addMember => $_getN(1);
  @$pb.TagNumber(2)
  set addMember($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAddMember() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddMember() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get removeMember => $_getN(2);
  @$pb.TagNumber(3)
  set removeMember($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRemoveMember() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoveMember() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get keyUpdate => $_getN(3);
  @$pb.TagNumber(4)
  set keyUpdate($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasKeyUpdate() => $_has(3);
  @$pb.TagNumber(4)
  void clearKeyUpdate() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get leaveGroup => $_getN(4);
  @$pb.TagNumber(5)
  set leaveGroup($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasLeaveGroup() => $_has(4);
  @$pb.TagNumber(5)
  void clearLeaveGroup() => clearField(5);

  @$pb.TagNumber(10)
  $core.List<$core.int> get dropGroup => $_getN(5);
  @$pb.TagNumber(10)
  set dropGroup($core.List<$core.int> v) { $_setBytes(5, v); }
  @$pb.TagNumber(10)
  $core.bool hasDropGroup() => $_has(5);
  @$pb.TagNumber(10)
  void clearDropGroup() => clearField(10);
}

class FrameTBS extends $pb.GeneratedMessage {
  factory FrameTBS({
    $core.String? groupId,
    $fixnum.Int64? epoch,
    $core.List<$core.int>? nonce,
    GroupOperation? groupOperation,
    $core.List<$core.int>? protectedPayload,
  }) {
    final $result = create();
    if (groupId != null) {
      $result.groupId = groupId;
    }
    if (epoch != null) {
      $result.epoch = epoch;
    }
    if (nonce != null) {
      $result.nonce = nonce;
    }
    if (groupOperation != null) {
      $result.groupOperation = groupOperation;
    }
    if (protectedPayload != null) {
      $result.protectedPayload = protectedPayload;
    }
    return $result;
  }
  FrameTBS._() : super();
  factory FrameTBS.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FrameTBS.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FrameTBS', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'epoch', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..aOM<GroupOperation>(5, _omitFieldNames ? '' : 'groupOperation', subBuilder: GroupOperation.create)
    ..a<$core.List<$core.int>>(6, _omitFieldNames ? '' : 'protectedPayload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FrameTBS clone() => FrameTBS()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FrameTBS copyWith(void Function(FrameTBS) updates) => super.copyWith((message) => updates(message as FrameTBS)) as FrameTBS;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FrameTBS create() => FrameTBS._();
  FrameTBS createEmptyInstance() => create();
  static $pb.PbList<FrameTBS> createRepeated() => $pb.PbList<FrameTBS>();
  @$core.pragma('dart2js:noInline')
  static FrameTBS getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FrameTBS>(create);
  static FrameTBS? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get epoch => $_getI64(1);
  @$pb.TagNumber(2)
  set epoch($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEpoch() => $_has(1);
  @$pb.TagNumber(2)
  void clearEpoch() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get nonce => $_getN(2);
  @$pb.TagNumber(3)
  set nonce($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNonce() => $_has(2);
  @$pb.TagNumber(3)
  void clearNonce() => clearField(3);

  @$pb.TagNumber(5)
  GroupOperation get groupOperation => $_getN(3);
  @$pb.TagNumber(5)
  set groupOperation(GroupOperation v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasGroupOperation() => $_has(3);
  @$pb.TagNumber(5)
  void clearGroupOperation() => clearField(5);
  @$pb.TagNumber(5)
  GroupOperation ensureGroupOperation() => $_ensure(3);

  @$pb.TagNumber(6)
  $core.List<$core.int> get protectedPayload => $_getN(4);
  @$pb.TagNumber(6)
  set protectedPayload($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(6)
  $core.bool hasProtectedPayload() => $_has(4);
  @$pb.TagNumber(6)
  void clearProtectedPayload() => clearField(6);
}

/// main transport layer frame [client] -> [SP]
class Frame extends $pb.GeneratedMessage {
  factory Frame({
    FrameTBS? frame,
    $core.List<$core.int>? proof,
  }) {
    final $result = create();
    if (frame != null) {
      $result.frame = frame;
    }
    if (proof != null) {
      $result.proof = proof;
    }
    return $result;
  }
  Frame._() : super();
  factory Frame.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Frame.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Frame', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOM<FrameTBS>(1, _omitFieldNames ? '' : 'frame', subBuilder: FrameTBS.create)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'proof', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Frame clone() => Frame()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Frame copyWith(void Function(Frame) updates) => super.copyWith((message) => updates(message as Frame)) as Frame;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Frame create() => Frame._();
  Frame createEmptyInstance() => create();
  static $pb.PbList<Frame> createRepeated() => $pb.PbList<Frame>();
  @$core.pragma('dart2js:noInline')
  static Frame getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Frame>(create);
  static Frame? _defaultInstance;

  @$pb.TagNumber(1)
  FrameTBS get frame => $_getN(0);
  @$pb.TagNumber(1)
  set frame(FrameTBS v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasFrame() => $_has(0);
  @$pb.TagNumber(1)
  void clearFrame() => clearField(1);
  @$pb.TagNumber(1)
  FrameTBS ensureFrame() => $_ensure(0);

  @$pb.TagNumber(9)
  $core.List<$core.int> get proof => $_getN(1);
  @$pb.TagNumber(9)
  set proof($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(9)
  $core.bool hasProof() => $_has(1);
  @$pb.TagNumber(9)
  void clearProof() => clearField(9);
}

/// transport layer frame [SP] -> [client]
class SPFrame extends $pb.GeneratedMessage {
  factory SPFrame({
    $fixnum.Int64? seqNum,
    $0.Timestamp? created,
    Frame? frame,
  }) {
    final $result = create();
    if (seqNum != null) {
      $result.seqNum = seqNum;
    }
    if (created != null) {
      $result.created = created;
    }
    if (frame != null) {
      $result.frame = frame;
    }
    return $result;
  }
  SPFrame._() : super();
  factory SPFrame.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SPFrame.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SPFrame', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'seqNum', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<$0.Timestamp>(4, _omitFieldNames ? '' : 'created', subBuilder: $0.Timestamp.create)
    ..aOM<Frame>(5, _omitFieldNames ? '' : 'frame', subBuilder: Frame.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SPFrame clone() => SPFrame()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SPFrame copyWith(void Function(SPFrame) updates) => super.copyWith((message) => updates(message as SPFrame)) as SPFrame;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SPFrame create() => SPFrame._();
  SPFrame createEmptyInstance() => create();
  static $pb.PbList<SPFrame> createRepeated() => $pb.PbList<SPFrame>();
  @$core.pragma('dart2js:noInline')
  static SPFrame getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SPFrame>(create);
  static SPFrame? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seqNum => $_getI64(0);
  @$pb.TagNumber(1)
  set seqNum($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSeqNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeqNum() => clearField(1);

  @$pb.TagNumber(4)
  $0.Timestamp get created => $_getN(1);
  @$pb.TagNumber(4)
  set created($0.Timestamp v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasCreated() => $_has(1);
  @$pb.TagNumber(4)
  void clearCreated() => clearField(4);
  @$pb.TagNumber(4)
  $0.Timestamp ensureCreated() => $_ensure(1);

  @$pb.TagNumber(5)
  Frame get frame => $_getN(2);
  @$pb.TagNumber(5)
  set frame(Frame v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasFrame() => $_has(2);
  @$pb.TagNumber(5)
  void clearFrame() => clearField(5);
  @$pb.TagNumber(5)
  Frame ensureFrame() => $_ensure(2);
}

/// vector of SPFrames for SP
class SPFrames extends $pb.GeneratedMessage {
  factory SPFrames({
    $core.Iterable<SPFrame>? spFrames,
  }) {
    final $result = create();
    if (spFrames != null) {
      $result.spFrames.addAll(spFrames);
    }
    return $result;
  }
  SPFrames._() : super();
  factory SPFrames.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SPFrames.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SPFrames', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..pc<SPFrame>(1, _omitFieldNames ? '' : 'spFrames', $pb.PbFieldType.PM, subBuilder: SPFrame.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SPFrames clone() => SPFrames()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SPFrames copyWith(void Function(SPFrames) updates) => super.copyWith((message) => updates(message as SPFrames)) as SPFrames;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SPFrames create() => SPFrames._();
  SPFrames createEmptyInstance() => create();
  static $pb.PbList<SPFrames> createRepeated() => $pb.PbList<SPFrames>();
  @$core.pragma('dart2js:noInline')
  static SPFrames getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SPFrames>(create);
  static SPFrames? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SPFrame> get spFrames => $_getList(0);
}

enum ProtectedPayloadTBS_Sender {
  userId, 
  leafId, 
  notSet
}

class ProtectedPayloadTBS extends $pb.GeneratedMessage {
  factory ProtectedPayloadTBS({
    $fixnum.Int64? seqNum,
    $core.String? userId,
    $core.String? leafId,
    $0.Timestamp? created,
    $core.Iterable<Payload>? payload,
  }) {
    final $result = create();
    if (seqNum != null) {
      $result.seqNum = seqNum;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (leafId != null) {
      $result.leafId = leafId;
    }
    if (created != null) {
      $result.created = created;
    }
    if (payload != null) {
      $result.payload.addAll(payload);
    }
    return $result;
  }
  ProtectedPayloadTBS._() : super();
  factory ProtectedPayloadTBS.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProtectedPayloadTBS.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, ProtectedPayloadTBS_Sender> _ProtectedPayloadTBS_SenderByTag = {
    2 : ProtectedPayloadTBS_Sender.userId,
    3 : ProtectedPayloadTBS_Sender.leafId,
    0 : ProtectedPayloadTBS_Sender.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProtectedPayloadTBS', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [2, 3])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'seqNum', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'leafId')
    ..aOM<$0.Timestamp>(4, _omitFieldNames ? '' : 'created', subBuilder: $0.Timestamp.create)
    ..pc<Payload>(5, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.PM, subBuilder: Payload.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProtectedPayloadTBS clone() => ProtectedPayloadTBS()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProtectedPayloadTBS copyWith(void Function(ProtectedPayloadTBS) updates) => super.copyWith((message) => updates(message as ProtectedPayloadTBS)) as ProtectedPayloadTBS;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtectedPayloadTBS create() => ProtectedPayloadTBS._();
  ProtectedPayloadTBS createEmptyInstance() => create();
  static $pb.PbList<ProtectedPayloadTBS> createRepeated() => $pb.PbList<ProtectedPayloadTBS>();
  @$core.pragma('dart2js:noInline')
  static ProtectedPayloadTBS getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtectedPayloadTBS>(create);
  static ProtectedPayloadTBS? _defaultInstance;

  ProtectedPayloadTBS_Sender whichSender() => _ProtectedPayloadTBS_SenderByTag[$_whichOneof(0)]!;
  void clearSender() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get seqNum => $_getI64(0);
  @$pb.TagNumber(1)
  set seqNum($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSeqNum() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeqNum() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get leafId => $_getSZ(2);
  @$pb.TagNumber(3)
  set leafId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasLeafId() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeafId() => clearField(3);

  @$pb.TagNumber(4)
  $0.Timestamp get created => $_getN(3);
  @$pb.TagNumber(4)
  set created($0.Timestamp v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasCreated() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreated() => clearField(4);
  @$pb.TagNumber(4)
  $0.Timestamp ensureCreated() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.List<Payload> get payload => $_getList(4);
}

/// protected application layer message(decrypted Frame.protected_payload)
class ProtectedPayload extends $pb.GeneratedMessage {
  factory ProtectedPayload({
    ProtectedPayloadTBS? payload,
    $core.List<$core.int>? signature,
  }) {
    final $result = create();
    if (payload != null) {
      $result.payload = payload;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    return $result;
  }
  ProtectedPayload._() : super();
  factory ProtectedPayload.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProtectedPayload.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProtectedPayload', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOM<ProtectedPayloadTBS>(1, _omitFieldNames ? '' : 'payload', subBuilder: ProtectedPayloadTBS.create)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProtectedPayload clone() => ProtectedPayload()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProtectedPayload copyWith(void Function(ProtectedPayload) updates) => super.copyWith((message) => updates(message as ProtectedPayload)) as ProtectedPayload;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtectedPayload create() => ProtectedPayload._();
  ProtectedPayload createEmptyInstance() => create();
  static $pb.PbList<ProtectedPayload> createRepeated() => $pb.PbList<ProtectedPayload>();
  @$core.pragma('dart2js:noInline')
  static ProtectedPayload getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtectedPayload>(create);
  static ProtectedPayload? _defaultInstance;

  @$pb.TagNumber(1)
  ProtectedPayloadTBS get payload => $_getN(0);
  @$pb.TagNumber(1)
  set payload(ProtectedPayloadTBS v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasPayload() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayload() => clearField(1);
  @$pb.TagNumber(1)
  ProtectedPayloadTBS ensurePayload() => $_ensure(0);

  @$pb.TagNumber(9)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(9)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(9)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(9)
  void clearSignature() => clearField(9);
}

/// auxiliary protected invite data
class ProtectedInviteData extends $pb.GeneratedMessage {
  factory ProtectedInviteData({
    $core.String? groupId,
    $fixnum.Int64? epoch,
    $core.List<$core.int>? stageKey,
  }) {
    final $result = create();
    if (groupId != null) {
      $result.groupId = groupId;
    }
    if (epoch != null) {
      $result.epoch = epoch;
    }
    if (stageKey != null) {
      $result.stageKey = stageKey;
    }
    return $result;
  }
  ProtectedInviteData._() : super();
  factory ProtectedInviteData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProtectedInviteData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProtectedInviteData', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'epoch', $pb.PbFieldType.OU6, defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'stageKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProtectedInviteData clone() => ProtectedInviteData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProtectedInviteData copyWith(void Function(ProtectedInviteData) updates) => super.copyWith((message) => updates(message as ProtectedInviteData)) as ProtectedInviteData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtectedInviteData create() => ProtectedInviteData._();
  ProtectedInviteData createEmptyInstance() => create();
  static $pb.PbList<ProtectedInviteData> createRepeated() => $pb.PbList<ProtectedInviteData>();
  @$core.pragma('dart2js:noInline')
  static ProtectedInviteData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtectedInviteData>(create);
  static ProtectedInviteData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get epoch => $_getI64(1);
  @$pb.TagNumber(2)
  set epoch($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEpoch() => $_has(1);
  @$pb.TagNumber(2)
  void clearEpoch() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get stageKey => $_getN(2);
  @$pb.TagNumber(3)
  set stageKey($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasStageKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearStageKey() => clearField(3);
}

/// Invite for some identified user (Q_id, Q_spk)
class IdentifiedInvite extends $pb.GeneratedMessage {
  factory IdentifiedInvite({
    $core.List<$core.int>? identityPublicKey,
    $core.List<$core.int>? spkPublicKey,
  }) {
    final $result = create();
    if (identityPublicKey != null) {
      $result.identityPublicKey = identityPublicKey;
    }
    if (spkPublicKey != null) {
      $result.spkPublicKey = spkPublicKey;
    }
    return $result;
  }
  IdentifiedInvite._() : super();
  factory IdentifiedInvite.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory IdentifiedInvite.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'IdentifiedInvite', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(1, _omitFieldNames ? '' : 'identityPublicKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'spkPublicKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  IdentifiedInvite clone() => IdentifiedInvite()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  IdentifiedInvite copyWith(void Function(IdentifiedInvite) updates) => super.copyWith((message) => updates(message as IdentifiedInvite)) as IdentifiedInvite;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IdentifiedInvite create() => IdentifiedInvite._();
  IdentifiedInvite createEmptyInstance() => create();
  static $pb.PbList<IdentifiedInvite> createRepeated() => $pb.PbList<IdentifiedInvite>();
  @$core.pragma('dart2js:noInline')
  static IdentifiedInvite getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IdentifiedInvite>(create);
  static IdentifiedInvite? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get identityPublicKey => $_getN(0);
  @$pb.TagNumber(1)
  set identityPublicKey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIdentityPublicKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentityPublicKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get spkPublicKey => $_getN(1);
  @$pb.TagNumber(2)
  set spkPublicKey($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSpkPublicKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSpkPublicKey() => clearField(2);
}

/// Invite for unidentified user
class UnidentifiedInvite extends $pb.GeneratedMessage {
  factory UnidentifiedInvite({
    $core.List<$core.int>? privateKey,
  }) {
    final $result = create();
    if (privateKey != null) {
      $result.privateKey = privateKey;
    }
    return $result;
  }
  UnidentifiedInvite._() : super();
  factory UnidentifiedInvite.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnidentifiedInvite.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnidentifiedInvite', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..a<$core.List<$core.int>>(3, _omitFieldNames ? '' : 'privateKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnidentifiedInvite clone() => UnidentifiedInvite()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnidentifiedInvite copyWith(void Function(UnidentifiedInvite) updates) => super.copyWith((message) => updates(message as UnidentifiedInvite)) as UnidentifiedInvite;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnidentifiedInvite create() => UnidentifiedInvite._();
  UnidentifiedInvite createEmptyInstance() => create();
  static $pb.PbList<UnidentifiedInvite> createRepeated() => $pb.PbList<UnidentifiedInvite>();
  @$core.pragma('dart2js:noInline')
  static UnidentifiedInvite getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnidentifiedInvite>(create);
  static UnidentifiedInvite? _defaultInstance;

  @$pb.TagNumber(3)
  $core.List<$core.int> get privateKey => $_getN(0);
  @$pb.TagNumber(3)
  set privateKey($core.List<$core.int> v) { $_setBytes(0, v); }
  @$pb.TagNumber(3)
  $core.bool hasPrivateKey() => $_has(0);
  @$pb.TagNumber(3)
  void clearPrivateKey() => clearField(3);
}

enum InviteTbs_Invite {
  identifiedInvite, 
  unidentifiedInvite, 
  notSet
}

class InviteTbs extends $pb.GeneratedMessage {
  factory InviteTbs({
    IdentifiedInvite? identifiedInvite,
    UnidentifiedInvite? unidentifiedInvite,
    $core.List<$core.int>? protectedInviteData,
    $core.List<$core.int>? identityPublicKey,
    $core.List<$core.int>? ephemeralPublicKey,
  }) {
    final $result = create();
    if (identifiedInvite != null) {
      $result.identifiedInvite = identifiedInvite;
    }
    if (unidentifiedInvite != null) {
      $result.unidentifiedInvite = unidentifiedInvite;
    }
    if (protectedInviteData != null) {
      $result.protectedInviteData = protectedInviteData;
    }
    if (identityPublicKey != null) {
      $result.identityPublicKey = identityPublicKey;
    }
    if (ephemeralPublicKey != null) {
      $result.ephemeralPublicKey = ephemeralPublicKey;
    }
    return $result;
  }
  InviteTbs._() : super();
  factory InviteTbs.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InviteTbs.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, InviteTbs_Invite> _InviteTbs_InviteByTag = {
    1 : InviteTbs_Invite.identifiedInvite,
    2 : InviteTbs_Invite.unidentifiedInvite,
    0 : InviteTbs_Invite.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InviteTbs', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<IdentifiedInvite>(1, _omitFieldNames ? '' : 'identifiedInvite', subBuilder: IdentifiedInvite.create)
    ..aOM<UnidentifiedInvite>(2, _omitFieldNames ? '' : 'unidentifiedInvite', subBuilder: UnidentifiedInvite.create)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'protectedInviteData', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(10, _omitFieldNames ? '' : 'identityPublicKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(11, _omitFieldNames ? '' : 'ephemeralPublicKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InviteTbs clone() => InviteTbs()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InviteTbs copyWith(void Function(InviteTbs) updates) => super.copyWith((message) => updates(message as InviteTbs)) as InviteTbs;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InviteTbs create() => InviteTbs._();
  InviteTbs createEmptyInstance() => create();
  static $pb.PbList<InviteTbs> createRepeated() => $pb.PbList<InviteTbs>();
  @$core.pragma('dart2js:noInline')
  static InviteTbs getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InviteTbs>(create);
  static InviteTbs? _defaultInstance;

  InviteTbs_Invite whichInvite() => _InviteTbs_InviteByTag[$_whichOneof(0)]!;
  void clearInvite() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  IdentifiedInvite get identifiedInvite => $_getN(0);
  @$pb.TagNumber(1)
  set identifiedInvite(IdentifiedInvite v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasIdentifiedInvite() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentifiedInvite() => clearField(1);
  @$pb.TagNumber(1)
  IdentifiedInvite ensureIdentifiedInvite() => $_ensure(0);

  @$pb.TagNumber(2)
  UnidentifiedInvite get unidentifiedInvite => $_getN(1);
  @$pb.TagNumber(2)
  set unidentifiedInvite(UnidentifiedInvite v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUnidentifiedInvite() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnidentifiedInvite() => clearField(2);
  @$pb.TagNumber(2)
  UnidentifiedInvite ensureUnidentifiedInvite() => $_ensure(1);

  @$pb.TagNumber(9)
  $core.List<$core.int> get protectedInviteData => $_getN(2);
  @$pb.TagNumber(9)
  set protectedInviteData($core.List<$core.int> v) { $_setBytes(2, v); }
  @$pb.TagNumber(9)
  $core.bool hasProtectedInviteData() => $_has(2);
  @$pb.TagNumber(9)
  void clearProtectedInviteData() => clearField(9);

  @$pb.TagNumber(10)
  $core.List<$core.int> get identityPublicKey => $_getN(3);
  @$pb.TagNumber(10)
  set identityPublicKey($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(10)
  $core.bool hasIdentityPublicKey() => $_has(3);
  @$pb.TagNumber(10)
  void clearIdentityPublicKey() => clearField(10);

  @$pb.TagNumber(11)
  $core.List<$core.int> get ephemeralPublicKey => $_getN(4);
  @$pb.TagNumber(11)
  set ephemeralPublicKey($core.List<$core.int> v) { $_setBytes(4, v); }
  @$pb.TagNumber(11)
  $core.bool hasEphemeralPublicKey() => $_has(4);
  @$pb.TagNumber(11)
  void clearEphemeralPublicKey() => clearField(11);
}

class Invite extends $pb.GeneratedMessage {
  factory Invite({
    InviteTbs? invite,
    $core.List<$core.int>? signature,
  }) {
    final $result = create();
    if (invite != null) {
      $result.invite = invite;
    }
    if (signature != null) {
      $result.signature = signature;
    }
    return $result;
  }
  Invite._() : super();
  factory Invite.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Invite.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Invite', package: const $pb.PackageName(_omitMessageNames ? '' : 'zero_art_proto'), createEmptyInstance: create)
    ..aOM<InviteTbs>(1, _omitFieldNames ? '' : 'invite', subBuilder: InviteTbs.create)
    ..a<$core.List<$core.int>>(9, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Invite clone() => Invite()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Invite copyWith(void Function(Invite) updates) => super.copyWith((message) => updates(message as Invite)) as Invite;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Invite create() => Invite._();
  Invite createEmptyInstance() => create();
  static $pb.PbList<Invite> createRepeated() => $pb.PbList<Invite>();
  @$core.pragma('dart2js:noInline')
  static Invite getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Invite>(create);
  static Invite? _defaultInstance;

  @$pb.TagNumber(1)
  InviteTbs get invite => $_getN(0);
  @$pb.TagNumber(1)
  set invite(InviteTbs v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvite() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvite() => clearField(1);
  @$pb.TagNumber(1)
  InviteTbs ensureInvite() => $_ensure(0);

  @$pb.TagNumber(9)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(9)
  set signature($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(9)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(9)
  void clearSignature() => clearField(9);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
