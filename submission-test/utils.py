"""
The University of Queensland
Semester 1 2023 COMS3200 Assignment 1 Part C

author: Jamie Katsamatsas 
student id: 46747200

This file implements widely used utility methods.
"""
from datetime import datetime

def get_time() -> str:
    """
    Returns the time in 24 hour hh:mm:ss format as a string.
    """
    return datetime.now().strftime("%H:%M:%S")