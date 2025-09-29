use ark_ec::{AffineRepr, CurveGroup};
use ark_ff::UniformRand;
use ark_std::rand::{SeedableRng, rngs::StdRng, thread_rng};
use cortado::{self, CortadoAffine, Fr as ScalarField};

pub struct SecretsFactory {
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
    pub fn new(seed: [u8; 32]) -> Self {
        Self {
            rng: StdRng::from_seed(seed),
        }
    }

    pub fn generate_secret(&mut self) -> ScalarField {
        ScalarField::rand(&mut self.rng)
    }

    pub fn generate_secret_with_public_key(&mut self) -> (CortadoAffine, ScalarField) {
        let secret_key = self.generate_secret();
        let public_key = (CortadoAffine::generator() * secret_key).into_affine();

        println!("SecretsFactory: Generated public key: {:?}", public_key);
        println!("SecretsFactory: Generated secret key: {:?}", secret_key);

        (public_key, secret_key)
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
