pub mod api;
mod frb_generated;

pub(crate) mod test {
    use std::{
        any, fs::File, io::Write, str::FromStr, time::{SystemTime, UNIX_EPOCH}
    };

    use anyhow::Ok;
    use automerge::{
        patches::TextRepresentation, sync::{Message, State, SyncDoc}, transaction::{CommitOptions, Transactable}, ActorId, AutoCommit, PatchLog, SaveOptions, TextEncoding
    };
    use graphviz_rust::{cmd::Format, printer::PrinterContext};

    use crate::api::{self, automerge::generate_actor_id};

    #[test]
    fn bautomerge_flow() -> anyhow::Result<()> {
        let mut autocommit = api::automerge::BAutoCommit::new();

        autocommit.insert_block(0, "hello".to_string())?;
        autocommit.insert_block(1, "world".to_string())?;
        autocommit.insert_block(2, "!!!!".to_string())?;
        autocommit.save_incremental();

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );
        println!(
            "Block with index {}: {}",
            1,
            autocommit.get_block(1).unwrap()
        );
        println!(
            "Block with index {}: {}",
            2,
            autocommit.get_block(2).unwrap()
        );

        println!("Delete block at index 2");
        autocommit.delete_block(2)?;

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );

        println!("Update block at index 0");
        autocommit.update_block(0, "hlloe".to_string())?;

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );

        println!("Save changes");
        autocommit.save_incremental();

        println!("All blocks:");
        for (i, block) in autocommit.get_blocks()?.iter().enumerate() {
            println!("Block with index {}: {}", i, block);
        }

        Ok(())
    }

    #[test]
    fn insert_overrides() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();

        automerge.insert_block(0, "hello".to_string())?;

        // overrides existing block, previous value will be moved to next index
        automerge.insert_block(0, "world".to_string())?;

        println!("Blocks #1: {:?}", automerge.get_blocks());

        assert!(automerge.blocks_length() == 2);
        assert!(automerge.delete_block(1).is_ok());

        println!("Blocks #2: {:?}", automerge.get_blocks());

        Ok(())
    }

    #[test]
    fn empty_get_blocks() -> anyhow::Result<()> {
        let automerge = api::automerge::BAutoCommit::new();

        automerge.get_blocks()?;

        assert!(automerge.blocks_length() == 1);

        Ok(())
    }

    #[test]
    fn duplicate_block() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.insert_block(0, '2'.to_string())?;

        let block = automerge.get_block(0)?;

        assert!(block == '2'.to_string());

        Ok(())
    }

    #[test]
    fn test_timestamp() -> anyhow::Result<()> {
        let mut automerge = AutoCommit::new();

        let lbl = automerge.put_object(automerge::ROOT, "test", automerge::ObjType::List)?;
        automerge.insert(lbl, 0, "")?;

        let start = SystemTime::now();
        let since_the_epoch = start
            .duration_since(UNIX_EPOCH)
            .expect("time should go forward")
            .as_secs();

        automerge.commit_with(CommitOptions::default().with_time(since_the_epoch as i64));

        let changes = automerge.get_changes(&[]);
        println!("{:?}", changes[0].timestamp());

        Ok(())
    }

    #[test]
    fn test_btimestamp() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();
        automerge.setup_block_label()?;
        automerge.insert_block(0, "hello".to_string())?;
        automerge.commit();

        automerge
            .get_change_list()
            .iter()
            .for_each(|e| println!("{:?}", e.timestamp()));

        println!("--------Changes--------");
        let mut automerge2 = api::automerge::BAutoCommit::new();

        automerge2
            .get_change_list()
            .iter()
            .for_each(|e| println!("{:?}", e.timestamp()));

        Ok(())
    }

    #[test]
    fn block_list_test() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();
        assert!(automerge.block_list_exist().unwrap() == false);

        automerge.setup_block_label().unwrap();
        assert!(automerge.block_list_exist().unwrap());

        automerge.commit();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.insert_block(1, '5'.to_string())?;

        automerge
            .get_change_list()
            .iter()
            .for_each(|e| println!("{:?}", e.timestamp()));

        Ok(())
    }

    #[test]
    fn test_fork_at_change_hash() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();
        automerge.setup_block_label().unwrap();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.commit();
        automerge.insert_block(1, '5'.to_string())?;
        automerge.commit();
        automerge.insert_block(2, "10".to_string())?;
        automerge.commit();

        let change_list = automerge.get_change_list();
        println!("{:?}", change_list);

        let mut automerge2 = automerge.doc_at_change_hash(&change_list[1].change_hash())?;

        let change_list = automerge2.get_blocks();
        println!("{:?}", change_list);

        Ok(())
    }

    #[test]
    fn test_diff() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();
        automerge.setup_block_label().unwrap();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.insert_block(1, "323231231".to_string())?;
        automerge.commit();

        let before = &automerge.get_change_list().last().unwrap().change_hash();

        // automerge.update_block(1, "32323123155".to_string())?;
        automerge.delete_block(1)?;
        automerge.commit();

        let after: &String = &automerge.get_change_list().last().unwrap().change_hash();

        // println!("{:?}", automerge.diff_between(before, after).unwrap());
        Ok(())
    }

    #[test]
    fn test_changes() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();
        automerge.setup_block_label().unwrap();
        automerge.commit();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.commit();
        automerge.update_block(0, '1'.to_string())?;
        automerge.commit();

        let change_list_len = automerge.get_change_list().len();
        println!("{:?}", change_list_len);
        Ok(())
    }

    #[test]
    fn patch_flow() -> anyhow::Result<()> {
        let actor_1 = generate_actor_id();
        let actor_2 = generate_actor_id();

        let mut bautomerge = api::automerge::BAutoCommit::new();
        bautomerge.set_actor_id(actor_1)?;

        bautomerge.setup_block_label()?;

        bautomerge.insert_block(0, "hello".to_string())?;
        bautomerge.insert_block(1, '5'.to_string())?;
        bautomerge.commit();

        bautomerge.set_actor_id(actor_2)?;

        bautomerge.insert_block(0, "ferferferf".to_string())?;
        bautomerge.update_block(1, "world".to_string())?;
        bautomerge.commit();

        let optree =  bautomerge.get_automerge().visualise_optree(None);

        let graph = graphviz_rust::parse(&optree).unwrap();
        let res = graphviz_rust::exec(graph, &mut PrinterContext::default(), vec![Format::Jpeg.into()]).unwrap();

        let mut file = File::create("output.jpeg").unwrap();
        file.write_all(&res).unwrap();



        Ok(())
    }


}
