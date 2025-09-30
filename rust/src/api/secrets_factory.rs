use aes_gcm::{aead::{Aead, Nonce}, Aes256Gcm, Key, KeyInit};
use ark_ec::{AffineRepr, CurveGroup};
use ark_ff::UniformRand;
use ark_std::rand::{rngs::StdRng, thread_rng, RngCore, SeedableRng};
use cortado::{self, CortadoAffine, Fr as ScalarField};

pub(crate) struct SecretsFactory {
    rng: StdRng,
}

impl Default for SecretsFactory {
    fn default() -> Self {
        Self {
            rng: StdRng::from_rng(thread_rng()).expect("Can't create rng from thread_rng"),
        }
    }
}

impl SecretsFactory {
    pub(crate) fn new(seed: [u8; 32]) -> Self {
        Self {
            rng: StdRng::from_seed(seed),
        }
    }

    pub(crate) fn generate_secret(&mut self) -> ScalarField {
        ScalarField::rand(&mut self.rng)
    }

    pub(crate) fn generate_secret_with_public_key(&mut self) -> (CortadoAffine, ScalarField) {
        let secret_key = self.generate_secret();
        let public_key = (CortadoAffine::generator() * secret_key).into_affine();

        println!("SecretsFactory: Generated public key: {:?}", public_key);
        println!("SecretsFactory: Generated secret key: {:?}", secret_key);

        (public_key, secret_key)
    }

    pub(crate) fn encrypt(&mut self, plaintext: &[u8]) -> Result<(Vec<u8>, Vec<u8>), aes_gcm::Error> {
        let mut okm = [0u8; 32 + 12];
        self.rng.fill_bytes(&mut okm);

        let (key, nonce) = (&okm[..32], &okm[32..]);
        let key = Key::<Aes256Gcm>::from_slice(key);
        let nonce = Nonce::<Aes256Gcm>::from_slice(&nonce);
        let cipher = Aes256Gcm::new(key);

        let ciphertext = cipher
            .encrypt(
                nonce,
                plaintext
            )?;
        Ok((ciphertext, okm.to_vec()))
    }

    pub(crate) fn decrypt(&self, ciphertext: &[u8], okm: &[u8]) -> Result<Vec<u8>, aes_gcm::Error> {
        let (key, nonce) = (&okm[..32], &okm[32..]);
        let key = Key::<Aes256Gcm>::from_slice(key);
        let nonce = Nonce::<Aes256Gcm>::from_slice(&nonce);
        let cipher = Aes256Gcm::new(key);        

        let plaintext = cipher
            .decrypt(
                nonce,
                ciphertext
            )?;
        Ok(plaintext)
    }
}

#[cfg(test)]
mod tests {
    use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
    use ark_std::rand::{rngs::StdRng, thread_rng, SeedableRng};
    use cortado::{self, CortadoAffine, Fr as ScalarField};

    use super::*;

    #[test]
    fn test_compression() {
        let mut secrets_factory = SecretsFactory::default();

        for i in 0..10000 {
            let (public_key, secret_key) = secrets_factory.generate_secret_with_public_key();
            
            let mut public_key_bytes = Vec::new();
            public_key.serialize_compressed(&mut public_key_bytes).unwrap();

            let public_key_2 = CortadoAffine::deserialize_compressed(&public_key_bytes[..]).unwrap();

            assert_eq!(public_key, public_key_2);

            
            let mut secret_key_bytes = Vec::new();
            secret_key.serialize_compressed(&mut secret_key_bytes).unwrap();

            let secret_key_2 = ScalarField::deserialize_compressed(&secret_key_bytes[..]).unwrap();

            assert_eq!(secret_key, secret_key_2);
        }
    }
}
