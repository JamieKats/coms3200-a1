from datetime import datetime

def get_time() -> str:
    """
    Returns the time in 24 hour hh:mm:ss format as a string.
    """
    return datetime.now().strftime("%H:%M:%S")