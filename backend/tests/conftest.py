import os

os.environ["COLLECT_ON_STARTUP"] = "false"
os.environ["ENABLE_SCHEDULER"] = "false"
os.environ.pop("DATABASE_URL", None)
os.environ.pop("ADMIN_API_KEY", None)
