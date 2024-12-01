# DB に入って打つコマンド

```bash
$ mysql -uisucon -D isupipe -p
```

```sql
ALTER TABLE `icons` ADD UNIQUE INDEX `idx_user_id` (`user_id`);
ALTER TABLE `livestream_tags` ADD INDEX `idx_livestream_id` (`livestream_id`);
ALTER TABLE `themes` ADD INDEX `idx_user_id` (`user_id`);

ALTER TABLE `icons` ADD COLUMN `icon_hash` TEXT;
```

---

```bash
$ mysql -uisucon -D isudns -p
```

```sql
ALTER TABLE `records` ADD INDEX `idx_name` (`name`);
```
