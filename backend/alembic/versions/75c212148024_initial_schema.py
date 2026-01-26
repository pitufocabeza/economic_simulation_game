from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM

# Revision identifiers, used by Alembic
revision = "initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Enums for the schema
    market_order_type_enum = ENUM("buy", "sell", name="marketordertype")
    market_order_type_enum.create(op.get_bind(), checkfirst=True)

    production_job_status_enum = ENUM("pending", "in_progress", "completed", "cancelled", name="productionjobstatus")
    production_job_status_enum.create(op.get_bind(), checkfirst=True)

    # goods table
    op.create_table(
        "goods",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False, unique=True),
    )

    # companies table
    op.create_table(
        "companies",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("cash", sa.Integer, nullable=False),
    )

    # inventory table
    op.create_table(
        "inventory",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("company_id", sa.Integer, sa.ForeignKey("companies.id"), nullable=False),
        sa.Column("good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("quantity", sa.Integer, nullable=False),
        sa.Column("reserved", sa.Integer, nullable=False, server_default="0"),
    )

    # production recipes table
    op.create_table(
        "productionrecipes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("input_good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("input_quantity", sa.Integer, nullable=False),
        sa.Column("output_good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("output_quantity", sa.Integer, nullable=False),
        sa.Column("duration_seconds", sa.Integer, nullable=False),
    )

    # market orders table
    op.create_table(
        "market_orders",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("order_type", sa.Enum("buy", "sell", name="marketordertype"), nullable=False),
        sa.Column("quantity", sa.Integer, nullable=False),
        sa.Column("price_per_unit", sa.Integer, nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("company_id", sa.Integer, sa.ForeignKey("companies.id"), nullable=False),
    )

    # production jobs table
    op.create_table(
        "production_jobs",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("company_id", sa.Integer, sa.ForeignKey("companies.id"), nullable=False),
        sa.Column("input_good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("output_good_id", sa.Integer, sa.ForeignKey("goods.id"), nullable=False),
        sa.Column("input_quantity", sa.Integer, nullable=False),
        sa.Column("output_quantity", sa.Integer, nullable=False),
        sa.Column("started_at", sa.DateTime, nullable=False),
        sa.Column("finishes_at", sa.DateTime, nullable=False),
        sa.Column("status", sa.Enum(
            "pending", "in_progress", "completed", "cancelled", name="productionjobstatus"
        ), nullable=False),
    )


def downgrade():
    op.drop_table("production_jobs")
    op.drop_table("market_orders")
    op.drop_table("productionrecipes")
    op.drop_table("inventory")
    op.drop_table("companies")
    op.drop_table("goods")

    ENUM(name="marketordertype").drop(op.get_bind(), checkfirst=True)
    ENUM(name="productionjobstatus").drop(op.get_bind(), checkfirst=True)