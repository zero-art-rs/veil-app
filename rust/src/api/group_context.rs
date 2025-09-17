use std::collections::HashMap;

use anyhow::{anyhow, bail};
use ark_ec::{AffineRepr, CurveGroup};
use ark_serialize::{
    serialize_to_vec, CanonicalDeserialize, CanonicalSerialize, SerializationError,
};
use awesome_client_sdk::{
    group_context::{
        builder::{
            CreateGroupContextBuilder, FromInviteGroupContextBuilder, GroupContextBuilder,
            InitialGroupContextBuilder,
        },
        GroupContext,
    },
    metadata, secrets_factory, zero_art_proto,
};
use cortado::{self, CortadoAffine, Fr as ScalarField};
use prost::Message;

pub struct BUser {
    user: metadata::user::User,
}

impl BUser {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(name: String, picture: Vec<u8>) -> Self {
        Self {
            user: metadata::user::User::new(name, picture, CortadoAffine::default()),
        }
    }
}

pub struct BGroupInfo {
    group_info: metadata::group::GroupInfo,
}

pub struct BGroupInfoBuilder {
    group_info_builder: metadata::group::GroupInfoBuilder,
}

impl BGroupInfoBuilder {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            group_info_builder: metadata::group::GroupInfoBuilder::new(),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn id(mut self, id: String) -> Self {
        self.group_info_builder = self.group_info_builder.id(id);
        self
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn name(mut self, name: String) -> Self {
        self.group_info_builder = self.group_info_builder.name(name);
        self
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn build(self) -> BGroupInfo {
        BGroupInfo {
            group_info: self.group_info_builder.build(),
        }
    }
}

pub struct BGroupContextBuilder {
    initial: Option<InitialGroupContextBuilder>,
    create: Option<CreateGroupContextBuilder>,
    from_invite: Option<FromInviteGroupContextBuilder>,
}

impl BGroupContextBuilder {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(identity_secret_key: Vec<u8>) -> anyhow::Result<Self> {
        let identity_secret_key =
            ScalarField::deserialize_uncompressed(&identity_secret_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let group_context_builder = GroupContextBuilder::new(identity_secret_key);

        Ok(Self {
            initial: Some(group_context_builder),
            create: None,
            from_invite: None,
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn create(
        mut self,
        leaf_secret: Vec<u8>,
        user: BUser,
        group_info: BGroupInfo,
    ) -> anyhow::Result<Self> {
        let leaf_secret = ScalarField::deserialize_uncompressed(&leaf_secret[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        self.create = Some(self.initial.take().unwrap().create(
            leaf_secret,
            user.user,
            group_info.group_info,
        ));
        Ok(self)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn identified_members_keys(
        mut self,
        identified_members_keys: Vec<(Vec<u8>, Option<Vec<u8>>)>,
    ) -> anyhow::Result<Self> {
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

        self.create = Some(
            self.create
                .take()
                .unwrap()
                .identified_members_keys(identified_members_keys),
        );
        Ok(self)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn unidentified_members_count(mut self, unidentified_members_count: usize) -> Self {
        self.create = Some(
            self.create
                .take()
                .unwrap()
                .unidentified_members_count(unidentified_members_count),
        );
        self
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn payload(mut self, payloads: Vec<Vec<u8>>) -> anyhow::Result<Self> {
        let payloads = payloads
            .into_iter()
            .map(|payload| {
                zero_art_proto::Payload::decode(&payload[..])
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))
            })
            .collect::<anyhow::Result<Vec<zero_art_proto::Payload>>>()?;

        self.create = Some(self.create.take().unwrap().payloads(payloads));
        Ok(self)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn build(
        self,
    ) -> anyhow::Result<(
        BGroupContext,
        Vec<u8>,
        HashMap<Vec<u8>, Vec<u8>>,
        Vec<Vec<u8>>,
    )> {
        let (group_context, frame, identified_invites, unidentified_invites) = self
            .create
            .unwrap()
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
}

pub struct BGroupContext {
    group_context: GroupContext,
}

impl BGroupContext {
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
    pub fn add_member(
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
                    .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))
            })
            .collect::<anyhow::Result<Vec<zero_art_proto::Payload>>>()?;

        let (frame, invite) = self
            .group_context
            .add_member(
                awesome_client_sdk::group_context::InvitationKeys::Identified {
                    identity_public_key,
                    spk_public_key,
                },
                payloads,
            )
            .map_err(|e| anyhow!("failed to add member: {}", e.to_string()))?;

        Ok((frame.encode_to_vec(), invite.encode_to_vec()))
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
