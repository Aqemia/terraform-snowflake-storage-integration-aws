locals {
  pipeline_bucket_ids = [
    for bucket_arn in var.data_bucket_arns : element(split(":::", bucket_arn), 1)
  ]
  storage_provider = length(regexall(".*gov.*", local.aws_region)) > 0 ? "S3GOV" : "S3"
}

resource "snowflake_storage_integration" "this" {
  provider = snowflake.storage_integration_role

  name    = "${upper(replace(var.prefix, "-", "_"))}_STORAGE_INTEGRATION"
  type    = "EXTERNAL_STAGE"
  enabled = true
  storage_allowed_locations = concat(
    ["${local.storage_provider}://${aws_s3_bucket.geff_bucket.id}/"],
    [for bucket_id in local.pipeline_bucket_ids : "s3://${bucket_id}/"]
  )
  storage_provider     = local.storage_provider
  storage_aws_role_arn = "arn:${var.arn_format}:iam::${local.account_id}:role/${local.s3_reader_role_name}"
}

resource "snowflake_grant_privileges_to_account_role" "this" {
  provider         = snowflake.storage_integration_role
  for_each         = var.snowflake_integration_user_roles

  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_storage_integration.this.name
  }

  privileges = ["USAGE"]
  account_role_name = each.key

  with_grant_option = false
}
