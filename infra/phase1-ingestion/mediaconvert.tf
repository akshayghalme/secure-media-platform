# --- MediaConvert Queue ---
# Dedicated queue for the ingestion pipeline with cost tracking

resource "aws_media_convert_queue" "ingestion" {
  name   = "${var.project_name}-ingestion-${var.environment}"
  status = "ACTIVE"

  tags = merge(local.common_tags, {
    Name = "Ingestion Queue"
  })
}
