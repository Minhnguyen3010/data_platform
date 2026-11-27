CREATE SUBSCRIPTION customers_sub
CONNECTION 'host=source port=5432 dbname=cdc_lab user=cdc_user password=cdc_local_only'
PUBLICATION customers_pub
WITH (copy_data = true);
