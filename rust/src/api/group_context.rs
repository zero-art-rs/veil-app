use anyhow::{anyhow, Result};
use ark_ec::{AffineRepr, CurveGroup};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use cortado::{self, CortadoAffine, Fr as ScalarField};
use prost::Message;
use sha3::{Digest, Sha3_256};
use std::str::FromStr;
use uuid::Uuid;
use zrt_art::types::PublicART;
use zrt_client_sdk::{
contexts::{group::{GroupContext, Nonce}, invite::InviteContext}, core::impls::concurrent::linear_keyed_validator::LinearKeyedValidator, models::{
        self,
        frame::Frame,
        invite::{Invite, Invitee},
        payload::Payload,
    }, utils::{deserialize, serialize}, zero_art_proto
};
use zrt_crypto::schnorr;

use crate::api::secrets_factory;

use tracing_subscriber;

#[flutter_rust_bridge::frb(sync)]
pub fn init_tracing() {
    let _ = tracing_subscriber::fmt()
        // .with_max_level(tracing::Level::TRACE) // щоб бачили trace/debug/info
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .try_init();
}

pub struct BUser {
    user: models::group_info::User,
}

#[flutter_rust_bridge::frb(sync)]
pub fn hash_public_key(pk: Vec<u8>) -> String {
    hex::encode(&Sha3_256::digest(pk)[..16])
}

#[flutter_rust_bridge::frb(sync)]
// sign spk pk with own sk
pub fn schnorr_sign(sk: Vec<u8>, message: Vec<u8>) -> Result<Vec<u8>> {
    let secret_key: ScalarField =
        deserialize(&sk).map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let public_key = (CortadoAffine::generator() * secret_key).into_affine();
    schnorr::sign(
        &vec![secret_key],
        &vec![public_key],
        &Sha3_256::digest(&message),
    )
    .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))
}

#[flutter_rust_bridge::frb(sync)]
pub fn schnorr_verify(pk: Vec<u8>, message: Vec<u8>, signature: Vec<u8>) -> Result<bool> {
    let public_key: CortadoAffine =
        deserialize(&pk).map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let result = schnorr::verify(&signature, &vec![public_key], &Sha3_256::digest(&message));

    match result {
        Err(_) => Ok(false),
        Ok(_) => Ok(true),
    }
}

impl BUser {
    #[flutter_rust_bridge::frb(sync)]
    pub fn name(&self) -> String {
        self.user.name.to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn new(name: String, public_key: Vec<u8>) -> Result<Self> {
        Ok(Self {
            user: models::group_info::User::new(
                name,
                deserialize(&public_key)
                    .map_err(|e| anyhow!("failed to join group, error: {}", e))?,
                vec![],
            ),
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn id(&self) -> String {
        self.user.id().to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn status(&self) -> i32 {
        self.user.status as i32
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
            group_info: models::group_info::GroupInfo::new(
                Uuid::parse_str(&id).unwrap(),
                name,
                chrono::Utc::now(),
                vec![],
            ),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn id(&self) -> String {
        self.group_info.id().to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn name(&self) -> String {
        self.group_info.name.to_string()
    }
}

pub struct BInviteContext {
    invite_context: InviteContext,
}

impl BInviteContext {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        identity_secret_key: Vec<u8>,
        spk_secret_key: Vec<u8>,
        invite: Vec<u8>,
    ) -> Result<Self> {
        let identity_secret_key = deserialize(&identity_secret_key)
            .map_err(|e| anyhow!("failed to deserialize identity secret key, error: {}", e))?;

        let spk_secret_key = if spk_secret_key.len() != 0 {
            Some(
                deserialize(&spk_secret_key)
                    .map_err(|e| anyhow!("failed to deserialize spk secret key, error: {}", e))?,
            )
        } else {
            None
        };

        let invite = Invite::decode(&invite)
            .map_err(|e| anyhow!("failed to decode invite, error: {}", e))?;

        Ok(Self {
            invite_context: InviteContext::new(identity_secret_key, spk_secret_key, invite)
                .map_err(|e| anyhow!("failed to create invite context, error: {}", e))?,
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn sign_as_identity(&self, msg: Vec<u8>) -> Result<Vec<u8>> {
        Ok(self
            .invite_context
            .sign_as_identity(&msg)
            .map_err(|e| anyhow!("failed to sign msg as identity, error: {}", e))?)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn sign_as_leaf(&self, msg: Vec<u8>) -> Result<Vec<u8>> {
        Ok(self
            .invite_context
            .sign_as_leaf(&msg)
            .map_err(|e| anyhow!("failed to sign msg as leaf, error: {}", e))?)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn upgrade(self, public_art: Vec<u8>) -> Result<BGroupContext> {
        let public_art: PublicART<CortadoAffine> = PublicART::deserialize(&public_art)
            .map_err(|e| anyhow!("failed to deserialize art, error: {}", e))?;
        Ok(BGroupContext {
            group_context: self
                .invite_context
                .upgrade(public_art)
                .map_err(|e| anyhow!("failed to sign msg as leaf, error: {}", e))?,
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn group_id(&self) -> String {
        self.invite_context.group_id().to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn epoch(&self) -> u64 {
        self.invite_context.epoch()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn leaf_public_key(&self) -> Result<Vec<u8>> {
        Ok(serialize(self.invite_context.leaf_public_key())
            .map_err(|e| anyhow!("failed to sign msg as leaf, error: {}", e))?)
    }

    // Additional impls
    #[flutter_rust_bridge::frb(sync)]
    pub fn sign_challenge(&self, nonce: Vec<u8>, challenge: Vec<u8>) -> Result<Vec<u8>> {
        let mut msg = Vec::new();
        msg.extend_from_slice(self.invite_context.group_id().as_bytes());
        msg.extend(&nonce);
        msg.extend(&challenge);
        msg.extend(self.invite_context.epoch().to_be_bytes());

        let signature = self
            .invite_context
            .sign_as_leaf(&Sha3_256::digest(msg))
            .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))?;

        Ok(signature)
    }
}

pub struct BGroupContext {
    group_context: GroupContext,
}

impl BGroupContext {
    #[flutter_rust_bridge::frb(sync)]
    pub fn from_parts(
        identity_secret_key: Vec<u8>,
        validator: Vec<u8>,
        group_info: Vec<u8>,
        epoch: u64,
        nonce: u64,
    ) -> Result<Self> {
        let identity_secret_key = ScalarField::deserialize_compressed(&identity_secret_key[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
        let validator = LinearKeyedValidator::deserialize(&validator).map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
        let group_info: models::group_info::GroupInfo =
            zero_art_proto::GroupInfo::decode(&group_info[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?
                .try_into()
                .map_err(|_| anyhow!("failed to parse stk"))?;

        Ok(Self {
            group_context: GroupContext::from_parts(identity_secret_key, validator, group_info, epoch, Nonce::new(nonce))
        })
    }

    pub fn into_parts(self) -> Result<(Vec<u8>, Vec<u8>, u64, u64)> {
        Ok(self.to_parts()?)
    }

    pub fn to_parts(&self) -> Result<(Vec<u8>, Vec<u8>, u64, u64)> {
        // let group_context = self.group_context.lock().unwrap();
        let (_, validator, group_info, epoch, nonce) = self.group_context.to_parts();

        let validator = validator.serialize().map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;
        let group_info = group_info.encode_to_vec();

        Ok((
            validator,
            group_info,
            epoch,
            nonce.value(),
        ))
    }

    pub fn join_group_as(&mut self, user: BUser) -> Result<Vec<u8>> {
        Ok(self
            .group_context
            .join_group_as(user.user)
            .map_err(|e| anyhow!("failed to join group: {}", e.to_string()))?
            .encode_to_vec()
            .map_err(|e| anyhow!("failed to encode vec: {}", e.to_string()))?)
    }


    pub fn process_frame(&mut self, frame: Vec<u8>) -> Result<(Vec<u8>, bool)> {
        // let mut group_context = self.group_context.lock().unwrap();

        let frame = Frame::decode(&frame)
            .map_err(|e| anyhow!("failed to deserialize frame: {}", e.to_string()))?;

        let content = self
            .group_context
            .process_frame(frame)
            .map_err(|e| anyhow!("failed to process_frame: {}", e.to_string()))?;

        Ok(content)
    }

    pub fn add_identified_member(
        &mut self,
        identity_public_key: Vec<u8>,
        spk_public_key: Option<Vec<u8>>,
        content: Vec<u8>,
    ) -> Result<(Vec<u8>, Vec<u8>)> {
        // let mut group_context = self.group_context.lock().unwrap();

        let identity_public_key =
            CortadoAffine::deserialize_compressed(&identity_public_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let spk_public_key = if let Some(spk_public_key) = spk_public_key {
            let spk_public_key = CortadoAffine::deserialize_compressed(&spk_public_key[..])
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
            Some(spk_public_key)
        } else {
            None
        };

        let (frame, invite) = self
            .group_context
            .add_member(
                Invitee::Identified {
                    identity_public_key,
                    spk_public_key,
                },
                content,
            )
            .map_err(|e| anyhow!("failed to add member: {}", e.to_string()))?;

        Ok((
            frame
                .encode_to_vec()
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
            invite
                .encode_to_vec()
                .map_err(|_| anyhow!("failed to deserialize"))?,
        ))
    }

    pub fn add_unidentified_member(
        &mut self,
        secret_key: Vec<u8>,
        content: Vec<u8>,
    ) -> Result<(Vec<u8>, Vec<u8>)> {
        // let mut group_context = self.group_context.lock().unwrap();

        let secret_key = ScalarField::deserialize_compressed(&secret_key[..])
            .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

        let (frame, invite) = self
            .group_context
            .add_member(Invitee::Unidentified(secret_key), content)
            .map_err(|e| anyhow!("failed to add member: {}", e.to_string()))?;

        Ok((
            frame
                .encode_to_vec()
                .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?,
            invite
                .encode_to_vec()
                .map_err(|_| anyhow!("failed to deserialize"))?,
        ))
    }

    pub fn remove_member(
        &mut self,
        user_id: String,
        content: Vec<u8>,
    ) -> Result<Vec<u8>> {
        // let mut group_context = self.group_context.lock().unwrap();

        let frame = self
            .group_context
            .remove_member(&user_id, content)
            .map_err(|e| anyhow!("failed to remove member: {}", e.to_string()))?;

        Ok(
            frame
                .encode_to_vec()
                .map_err(|_| anyhow!("failed to deserialize"))?,
        )
    }

    pub fn create_frame(&mut self, content: Vec<u8>) -> Result<Vec<u8>> {
        // let mut group_context = self.group_context.lock().unwrap();

        let frame = self
            .group_context
            .create_frame(content)
            .map_err(|e| anyhow!("failed to create frame: {}", e.to_string()))?;

        Ok(frame
            .encode_to_vec()
            .map_err(|_| anyhow!("failed to deserialize"))?)
    }

    pub fn leave_group(&mut self) -> Result<Vec<u8>> {
        let frame = self
            .group_context
            .leave_group()
            .map_err(|e| anyhow!("failed to create frame: {}", e.to_string()))?;

        Ok(frame
            .encode_to_vec()
            .map_err(|_| anyhow!("failed to deserialize"))?)
    }

    pub fn change_user(&mut self, name: Option<String>, picture: Option<Vec<u8>>) -> Result<Vec<u8>> {
        let frame = self
            .group_context
            .change_user(name, picture)
            .map_err(|e| anyhow!("failed to create frame: {}", e.to_string()))?;

        Ok(frame
            .encode_to_vec()
            .map_err(|_| anyhow!("failed to deserialize"))?)
    }

    pub fn change_group(&mut self, name: Option<String>, picture: Option<Vec<u8>>) -> Result<Vec<u8>> {
        let frame = self
            .group_context
            .change_group(name, picture)
            .map_err(|e| anyhow!("failed to create frame: {}", e.to_string()))?;

        Ok(frame
            .encode_to_vec()
            .map_err(|_| anyhow!("failed to deserialize"))?)
    }

    pub fn sign_with_tk(&self, group_id: String, nonce: Vec<u8>) -> Result<Vec<u8>> {
        // let group_context = self.group_context.lock().unwrap();

        let chat_uuid = Uuid::from_str(&group_id)?;
        let mut msg = Vec::new();
        msg.extend_from_slice(chat_uuid.as_bytes());
        msg.extend(&nonce);

        self.group_context
            .sign_with_tk(&Sha3_256::digest(msg))
            .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))
    }

    pub fn sign_challenge(&self, challenge: Vec<u8>) -> Result<Vec<u8>> {
        // let pending_group_context = self.pending_group_context.lock().unwrap();

        println!("Challenge: {:?}", challenge);
        println!("Hashed challenge: {:?}", Sha3_256::digest(&challenge));
        self.group_context
            .sign_with_tk(&Sha3_256::digest(challenge))
            .map_err(|e| anyhow!("failed to sign: {}", e.to_string()))
    }

    pub fn epoch(&self) -> u64 {
        self.group_context.epoch()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn group_info(&self) -> Vec<u8> {
        let group_info: zero_art_proto::GroupInfo = self.group_context.group_info().clone().into();
        group_info.encode_to_vec()
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
    pub fn generate_secret(&mut self) -> Result<Vec<u8>> {
        let secret_key = self.secrets_factory.generate_secret();
        let mut secret_key_bytes = Vec::new();
        secret_key
            .serialize_compressed(&mut secret_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;
        Ok(secret_key_bytes)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn generate_secret_with_public_key(&mut self) -> Result<(Vec<u8>, Vec<u8>)> {
        let (public_key, secret_key) = self.secrets_factory.generate_secret_with_public_key();

        let mut public_key_bytes = Vec::new();
        public_key
            .serialize_compressed(&mut public_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

        let mut secret_key_bytes = Vec::new();
        secret_key
            .serialize_compressed(&mut secret_key_bytes)
            .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

        Ok((public_key_bytes, secret_key_bytes))
    }
    #[flutter_rust_bridge::frb(sync)]
    /// Returns cipher text and encryption key
    pub fn encrypt(&mut self, plaintext: Vec<u8>) -> Result<(Vec<u8>, Vec<u8>)> {
        Ok(self
            .secrets_factory
            .encrypt(&plaintext)
            .map_err(|e| anyhow!("failed to encrypt: {}", e.to_string()))?)
    }

    #[flutter_rust_bridge::frb(sync)]
    /// Applies cipher text and encryption key, return plain text
    pub fn decrypt(&mut self, ciphertext: Vec<u8>, okm: Vec<u8>) -> Result<Vec<u8>> {
        Ok(self
            .secrets_factory
            .decrypt(&ciphertext, &okm)
            .map_err(|e| anyhow!("failed to decrypt: {}", e.to_string()))?)
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn public_key_from_secret_key(secret_key: Vec<u8>) -> Result<Vec<u8>> {
    let secret_key = ScalarField::deserialize_compressed(&secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    let public_key = (CortadoAffine::generator() * secret_key).into_affine();
    let mut public_key_bytes = Vec::new();
    public_key
        .serialize_compressed(&mut public_key_bytes)
        .map_err(|e| anyhow!("failed to serialize: {}", e.to_string()))?;

    Ok(public_key_bytes)
}

// #[flutter_rust_bridge::frb(sync)]
pub fn create_group(
    identity_secret_key: Vec<u8>,
    user: BUser,
    group_info: BGroupInfo,
) -> Result<(BGroupContext, Vec<u8>)> {
    let identity_secret_key = ScalarField::deserialize_compressed(&identity_secret_key[..])
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;


    let (group_context, frame) = GroupContext::new(identity_secret_key, user.user, group_info.group_info)
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;
    let frame = frame
        .encode_to_vec()
        .map_err(|e| anyhow!("failed to deserialize: {}", e.to_string()))?;

    Ok((
        BGroupContext {
            group_context: group_context,
        },
        frame,
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn hash_publcih_key(pk: Vec<u8>) -> String {
    hex::encode(&Sha3_256::digest(pk)[..16])
}
