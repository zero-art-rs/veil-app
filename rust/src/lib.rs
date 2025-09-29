pub mod api;
mod frb_generated;

pub(crate) mod test {
    use std::{
        any,
        fs::File,
        io::Write,
        str::FromStr,
        time::{SystemTime, UNIX_EPOCH},
    };

    use anyhow::Ok;
    use automerge::{
        patches::TextRepresentation,
        sync::{Message, State, SyncDoc},
        transaction::{CommitOptions, Transactable},
        ActorId, AutoCommit, PatchLog, SaveOptions, TextEncoding,
    };
    use graphviz_rust::{cmd::Format, printer::PrinterContext};

    use crate::api::{
        self,
        automerge::{generate_actor_id, BAutoCommit},
    };
    
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

        bautomerge.insert_block(0, "hello".to_string())?;
        bautomerge.insert_block(1, '5'.to_string())?;
        bautomerge.commit();

        bautomerge.set_actor_id(actor_2)?;

        bautomerge.insert_block(0, "ferferferf".to_string())?;
        bautomerge.update_block(1, "world".to_string())?;
        bautomerge.commit();

        let optree = bautomerge.get_automerge().visualise_optree(None);

        let graph = graphviz_rust::parse(&optree).unwrap();
        let res = graphviz_rust::exec(
            graph,
            &mut PrinterContext::default(),
            vec![Format::Jpeg.into()],
        )
        .unwrap();

        let mut file = File::create("output.jpeg").unwrap();
        file.write_all(&res).unwrap();

        Ok(())
    }

    #[test]
    fn incremental_change() -> anyhow::Result<()> {
        let actor_id = generate_actor_id();

        println!("actor 1 {:?}", actor_id);

        let mut automerge = api::automerge::BAutoCommit::new();
        automerge.set_actor_id(actor_id)?;

        automerge.insert_block(0, '1'.to_string())?;
        automerge.insert_block(1, '5'.to_string())?;
        automerge.commit();

        let actor_2 = generate_actor_id();
        println!("actor 2 {:?}", actor_2);
        let mut automerge2 = api::automerge::BAutoCommit::new();
        automerge2.set_actor_id(generate_actor_id())?;
        automerge2.load_incremental(automerge.save_incremental())?;

        automerge2.insert_block(0, '2'.to_string())?;
        automerge2.commit();

        automerge.insert_block(2, "10".to_string())?;
        automerge.commit();

        automerge2.load_incremental(automerge.save_incremental())?;
        automerge2.empty_change();
        automerge2.commit();

        automerge.load_incremental(automerge2.save_incremental())?;
        automerge.empty_change();
        automerge.commit();

        println!("automerge2 {:?}", automerge2.get_blocks());
        println!("automerge {:?}", automerge.get_blocks());

        println!("automerge2 change list: {:?}", automerge2.get_change_list());
        println!("automerge change list: {:?}", automerge.get_change_list());

        // assert!(automerge2.get_change_list() == automerge.get_change_list());

        // automerge2.insert_block(4, "20".to_string())?;
        // automerge2.commit();

        // automerge.load_incremental(automerge2.save_incremental())

        // let blocks = automerge2.get_blocks()?;
        // println!("{:?}", blocks);

        // let change_list = automerge2.get_change_list();
        // println!("{:?}", change_list);

        Ok(())
    }

    #[test]
    fn test_load() -> anyhow::Result<()> {
        let actor_id = generate_actor_id();

        println!("actor 1 {:?}", actor_id);

        let mut automerge_1 = api::automerge::BAutoCommit::new();
        automerge_1.set_actor_id(actor_id)?;

        automerge_1.insert_block(0, "10".to_string())?;
        automerge_1.insert_block(1, "20".to_string())?;
        automerge_1.insert_block(2, "30".to_string())?;
        automerge_1.commit();

        // let mut automerge_2 = api::automerge::BAutoCommit::new();
        // automerge_2.setup_block_label()?;

        let mut autocommit = BAutoCommit::load(automerge_1.save())?;

        let blocks = autocommit.get_blocks()?;
        println!("{:?}", blocks);

        let changes = autocommit.get_change_list();
        println!("{:?}", changes);

        Ok(())
    }

    #[test]
    fn test_conflict_on_block() -> anyhow::Result<()> {
        let actor_id_1 = generate_actor_id();
        let actor_id_2 = generate_actor_id();

        println!("actor 1 {:?}", actor_id_1);

        let mut automerge_1 = api::automerge::BAutoCommit::new();
        automerge_1.set_actor_id(actor_id_1)?;

        automerge_1.insert_block(0, "1".to_string())?;
        automerge_1.insert_block(1, "2".to_string())?;
        automerge_1.commit();

        let mut automerge_2 = api::automerge::BAutoCommit::from_bytes(automerge_1.save())?;
        automerge_2.set_actor_id(actor_id_2)?;

        automerge_2.insert_block(2, "hello world".to_string())?;
        automerge_2.commit();
        // sync state between
        automerge_1.load_incremental(automerge_2.save_incremental())?;

        automerge_1.update_block(2, "hello world 2".to_string())?;
        automerge_1.insert_block(3, "block 3".to_string())?;

        automerge_2.update_block(2, "ewkfergfjkenwrgkjnergjkn".to_string())?;
        automerge_2.commit();

        automerge_1.commit();
        automerge_1.load_incremental(automerge_2.save_incremental())?;

        automerge_2.load_incremental(automerge_1.save_incremental())?;

        println!("automerge_1 content {:?}", automerge_1.get_blocks());
        println!("automerge_2 content {:?}", automerge_2.get_blocks());

        Ok(())
    }
}
