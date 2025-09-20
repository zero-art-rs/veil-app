use anyhow::anyhow;
use ark_ec::{AffineRepr, CurveGroup};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use awesome_client_sdk::{
    group_context::{builder::GroupContextBuilder, GroupContext},
    models, secrets_factory, zero_art_proto,
};
use cortado::{self, CortadoAffine, Fr as ScalarField};
use crypto::schnorr;
use prost::Message;
use sha3::{Digest, Sha3_256};
use std::{collections::HashMap, str::FromStr};
use uuid::Uuid;

pub struct BUser {
    user: models::group_info::User,
}

impl BUser {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(id: String, name: String) -> Self {
        Self {
            user: models::group_info::User {
                id,
                name,
                public_key: CortadoAffine::default(),
                metadata: vec![],
                role: zero_art_proto::Role::Ownership,
            },
        }
    }
}

pub struct BGroupInfo {
    group_info: models::group_info::GroupInfo,
}

// empty since we are not going to invite members in create group stage yet.
impl BGroupInfo {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(id: String, name: String) -> Self {
        Self {
            group_info: models::group_info::GroupInfo {
                id: Uuid::parse_str(&id).unwrap(),
                name,
                metadata: vec![],
                created: chrono::Utc::now(),
                members: models::group_info::GroupMembers::default(),
            },
        }
    }
}

pub struct BGroupContext {
    group_context: GroupContext,
}

impl BGroupContext {
    #[flutter_rust_bridge::frb(sync)]
    pub fn from_parts(
        identity_secret_key: Vec<u8>,
        leaf_secret: Vec<u8>,
        art: Vec<u8>,
        stk: Vec<u8>,
        epoch: u64,
        group_info: Vec<u8>,
    ) -> anyhow::Result<Self> {
        let identity_secret_key =
            ScalarField::deserialize_uncompressed(&identity_secret_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
        let leaf_secret = ScalarField::deserialize_uncompressed(&leaf_secret[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
        let stk: [u8; 32] = stk.try_into().map_err(|_| anyhow!("failed to parse stk"))?;
        let group_info: models::group_info::GroupInfo =
            zero_art_proto::GroupInfo::decode(&group_info[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?
                .try_into()
                .map_err(|_| anyhow!("failed to parse stk"))?;

        Ok(Self {
            group_context: GroupContext::from_parts(
                identity_secret_key,
                leaf_secret,
                &art,
                stk,
                epoch,
                0,
                group_info,
            )
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn into_parts(self) -> anyhow::Result<(Vec<u8>, Vec<u8>, Vec<u8>, u64, Vec<u8>)> {
        self.group_context
            .into_parts()
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn process_frame(&mut self, sp_frame: Vec<u8>) -> anyhow::Result<Vec<Vec<u8>>> {
        let sp_frame = zero_art_proto::SpFrame::decode(&sp_frame[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
        let payloads = self
            .group_context
            .process_frame(sp_frame)
            .map_err(|e| anyhow!("failed to process_frame: {}", e.to_string()))?;
        let payloads = payloads.into_iter().map(|v| v.encode_to_vec()).collect();
        Ok(payloads)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn add_identified_member(
        &mut self,
        identity_public_key: Vec<u8>,
        spk_public_key: Option<Vec<u8>>,
        payloads: Vec<Vec<u8>>,
    ) -> anyhow::Result<(Vec<u8>, Vec<u8>)> {
        let identity_public_key = CortadoAffine::deserialize_uncompressed(&identity_public_key[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let spk_public_key = if let Some(spk_public_key) = spk_public_key {
            let spk_public_key = CortadoAffine::deserialize_uncompressed(&spk_public_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
            Some(spk_public_key)
        } else {
            None
        };

        let payloads = payloads
            .into_iter()
            .map(|v| {
                zero_art_proto::Payload::decode(&v[..])
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?
                    .try_into()
                    .map_err(|_| anyhow!("failed to deserialize"))
            })
            .collect::<anyhow::Result<Vec<models::payload::Payload>>>()?;

        let (frame, invite) = self
            .group_context
            .add_member(
                awesome_client_sdk::invite::Invitee::Identified {
                    identity_public_key,
                    spk_public_key,
                },
                payloads,
            )
            .map_err(|e| anyhow!("failed to add member: {}", e.to_string()))?;

        Ok((
            frame
                .encode_to_vec()
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
            invite.encode_to_vec(),
        ))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn add_unidentified_member(
        &mut self,
        secret_key: Vec<u8>,
        payloads: Vec<Vec<u8>>,
    ) -> anyhow::Result<(Vec<u8>, Vec<u8>)> {
        let secret_key = ScalarField::deserialize_uncompressed(&secret_key[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let payloads = payloads
            .into_iter()
            .map(|v| {
                zero_art_proto::Payload::decode(&v[..])
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?
                    .try_into()
                    .map_err(|_| anyhow!("failed to deserialize"))
            })
            .collect::<anyhow::Result<Vec<models::payload::Payload>>>()?;

        let (frame, invite) = self
            .group_context
            .add_member(
                awesome_client_sdk::invite::Invitee::Unidentified(secret_key),
                payloads,
            )
            .map_err(|e| anyhow!("failed to add member: {}", e.to_string()))?;

        Ok((
            frame
                .encode_to_vec()
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
            invite.encode_to_vec(),
        ))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn remove_member(
        &mut self,
        leaf_public_key: Vec<u8>,
        payload: Vec<u8>,
    ) -> anyhow::Result<Vec<u8>> {
        let leaf_public_key = CortadoAffine::deserialize_uncompressed(&leaf_public_key[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let frame = self
            .group_context
            .remove_member(leaf_public_key, &payload)
            .map_err(|e| anyhow!("failed to remove member: {}", e.to_string()))?;

        Ok(frame)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn create_frame(&mut self, payloads: Vec<Vec<u8>>) -> anyhow::Result<Vec<u8>> {
        let payloads = payloads
            .into_iter()
            .map(|v| {
                zero_art_proto::Payload::decode(&v[..])
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))
            })
            .collect::<anyhow::Result<Vec<zero_art_proto::Payload>>>()?;

        let frame = self
            .group_context
            .create_frame(payloads)
            .map_err(|e| anyhow!("failed to create frame: {}", e.to_string()))?;

        Ok(frame.encode_to_vec())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn sign_with_tk(&self, group_id: String, nonce: Vec<u8>) -> anyhow::Result<Vec<u8>> {
        let chat_uuid = Uuid::from_str(&group_id)?;
        let mut msg = Vec::new();
        msg.extend_from_slice(chat_uuid.as_bytes());
        msg.extend(&nonce);

        self.group_context
            .sign_with_tk(&Sha3_256::digest(msg))
            .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_epoch(&self) -> u64 {
        self.group_context.get_epoch()
    }
}

pub struct BSecretsFactory {
    secrets_factory: secrets_factory::SecretsFactory,
}

impl BSecretsFactory {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(seed: [u8; 32]) -> Self {
        Self {
            secrets_factory: secrets_factory::SecretsFactory::new(seed),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn generate_secret(&mut self) -> anyhow::Result<Vec<u8>> {
        let secret_key = self.secrets_factory.generate_secret();
        let mut secret_key_bytes = Vec::new();
        secret_key
            .serialize_uncompressed(&mut secret_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;
        Ok(secret_key_bytes)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn generate_secret_with_public_key(&mut self) -> anyhow::Result<(Vec<u8>, Vec<u8>)> {
        let (public_key, secret_key) = self.secrets_factory.generate_secret_with_public_key();

        let mut public_key_bytes = Vec::new();
        public_key
            .serialize_uncompressed(&mut public_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

        let mut secret_key_bytes = Vec::new();
        secret_key
            .serialize_uncompressed(&mut secret_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

        Ok((public_key_bytes, secret_key_bytes))
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn public_key_from_secret_key(secret_key: Vec<u8>) -> anyhow::Result<Vec<u8>> {
    let secret_key = ScalarField::deserialize_uncompressed(&secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let public_key = (CortadoAffine::generator() * secret_key).into_affine();
    let mut public_key_bytes = Vec::new();
    public_key
        .serialize_uncompressed(&mut public_key_bytes)
        .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

    Ok(public_key_bytes)
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_group(
    identity_secret_key: Vec<u8>,
    user: BUser,
    group_info: BGroupInfo,
    identified_members_keys: Vec<(Vec<u8>, Option<Vec<u8>>)>,
    unidentified_members_count: usize,
    payloads: Vec<Vec<u8>>,
) -> anyhow::Result<(
    BGroupContext,
    Vec<u8>,
    HashMap<Vec<u8>, Vec<u8>>,
    Vec<Vec<u8>>,
)> {
    let identity_secret_key = ScalarField::deserialize_uncompressed(&identity_secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let identified_members_keys = identified_members_keys
        .into_iter()
        .map(|(identity_public_key, ephemeral_public_key)| {
            let identity_public_key =
                CortadoAffine::deserialize_uncompressed(&identity_public_key[..])
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

            let ephemeral_public_key = match ephemeral_public_key {
                Some(ephemeral_public_key) => Some(
                    CortadoAffine::deserialize_uncompressed(&ephemeral_public_key[..])
                        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
                ),
                None => None,
            };
            Ok((identity_public_key, ephemeral_public_key))
        })
        .collect::<anyhow::Result<Vec<(CortadoAffine, Option<CortadoAffine>)>>>()?;

    let payloads = payloads
        .into_iter()
        .map(|payload| {
            zero_art_proto::Payload::decode(&payload[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))
        })
        .collect::<anyhow::Result<Vec<zero_art_proto::Payload>>>()?;

    let (group_context, frame, identified_invites, unidentified_invites) =
        GroupContextBuilder::new(identity_secret_key)
            .create(user.user, group_info.group_info)
            .identified_members_keys(identified_members_keys)
            .unidentified_members_count(unidentified_members_count)
            .payloads(payloads)
            .build()
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let frame = frame.encode_to_vec();
    let identified_invites = identified_invites
        .into_iter()
        .map(|(k, v)| (k, v.encode_to_vec()))
        .collect();
    let unidentified_invites = unidentified_invites
        .into_iter()
        .map(|i| i.encode_to_vec())
        .collect();

    Ok((
        BGroupContext { group_context },
        frame,
        identified_invites,
        unidentified_invites,
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_group_from_identified_invite(
    identity_secret_key: Vec<u8>,
    spk_secret_key: Vec<u8>,
    art: Vec<u8>,
    invite: Vec<u8>,
    user: BUser,
) -> anyhow::Result<(BGroupContext, Vec<u8>)> {
    let identity_secret_key = ScalarField::deserialize_uncompressed(&identity_secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let spk_secret_key = if spk_secret_key.len() == 0 {
        None
    } else {
        Some(
            ScalarField::deserialize_uncompressed(&spk_secret_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
        )
    };

    let invite = zero_art_proto::Invite::decode(&invite[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let (group_context, frame) =
        GroupContext::from_invite(identity_secret_key, spk_secret_key, art, invite, user.user)
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    Ok((
        BGroupContext { group_context },
        frame
            .encode_to_vec()
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?,
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_group_from_unidentified_invite(
    identity_secret_key: Vec<u8>,
    art: Vec<u8>,
    invite: Vec<u8>,
    user: BUser,
) -> anyhow::Result<(BGroupContext, Vec<u8>)> {
    let identity_secret_key = ScalarField::deserialize_uncompressed(&identity_secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let invite = zero_art_proto::Invite::decode(&invite[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let (group_context, frame) =
        GroupContext::from_invite(identity_secret_key, None, art, invite, user.user)
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    Ok((
        BGroupContext { group_context },
        frame
            .encode_to_vec()
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?,
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn destruct_identified_invite(
    invite: Vec<u8>,
    identity_secret_key: Vec<u8>,
    spk_secret_key: Vec<u8>,
) -> anyhow::Result<(Vec<u8>, Vec<u8>, u64, Vec<u8>)> {
    let identity_secret_key = ScalarField::deserialize_uncompressed(&identity_secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let spk_secret_key = if spk_secret_key.len() == 0 {
        None
    } else {
        Some(
            ScalarField::deserialize_uncompressed(&spk_secret_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
        )
    };

    let invite = zero_art_proto::Invite::decode(&invite[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let (invite, leaf_secret) = awesome_client_sdk::invite::Invite::try_from(
        invite,
        Some((identity_secret_key, spk_secret_key)),
    )
    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let mut leaf_secret_bytes = Vec::new();
    leaf_secret
        .serialize_uncompressed(&mut leaf_secret_bytes)
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let group_info: zero_art_proto::GroupInfo = invite.group_info.into();

    Ok((
        leaf_secret_bytes,
        invite.stage_key.to_vec(),
        invite.epoch,
        group_info.encode_to_vec(),
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn destruct_unidentified_invite(
    invite: Vec<u8>,
) -> anyhow::Result<(Vec<u8>, Vec<u8>, u64, Vec<u8>)> {
    let invite = zero_art_proto::Invite::decode(&invite[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let (invite, leaf_secret) = awesome_client_sdk::invite::Invite::try_from(invite, None)
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let mut leaf_secret_bytes = Vec::new();
    leaf_secret
        .serialize_uncompressed(&mut leaf_secret_bytes)
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let group_info: zero_art_proto::GroupInfo = invite.group_info.into();

    Ok((
        leaf_secret_bytes,
        invite.stage_key.to_vec(),
        invite.epoch,
        group_info.encode_to_vec(),
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn sign_challenge(
    leaf_secret: Vec<u8>,
    chat_id: String,
    nonce: Vec<u8>,
    challenge: Vec<u8>,
    epoch: u64,
) -> anyhow::Result<Vec<u8>> {
    let leaf_secret = ScalarField::deserialize_uncompressed(&leaf_secret[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let chat_uuid = Uuid::from_str(&chat_id)?;
    let mut msg = Vec::new();
    msg.extend_from_slice(chat_uuid.as_bytes());
    msg.extend(&nonce);
    msg.extend(&challenge);
    msg.extend(epoch.to_be_bytes());

    let leaf_public_key = (CortadoAffine::generator() * leaf_secret).into_affine();

    let signature = schnorr::sign(
        &vec![leaf_secret],
        &vec![leaf_public_key],
        &Sha3_256::digest(msg),
    )
    .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))?;

    Ok(signature)
}
