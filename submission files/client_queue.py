"""
The University of Queensland
Semester 1 2023 COMS3200 Assignment 1 Part C

author: Jamie Katsamatsas 
student id: 46747200

This file contains the implementation of a client queue. The client queue class
extends the list class.

TODO remove all instances of todo print statements in all files
"""
import threading
from utils import get_time
from server_client import ServerClient

class ClientQueue(list):
    """
    A thread safe FIFO queune to store clients in that allows removal at any 
    point in the queue.
    """
    def __init__(self) -> None:
        super().__init__()
        self.lock: threading.Lock = threading.Lock()
        
        
    def put(self, client: ServerClient, channel_name: str, spaces_in_chat_room: int) -> None:
        """
        Adds the client to the end of the queue in a threadsafe way.

        Args:
            user (ServerClient): client to be added to the queue
        """
        self.lock.acquire()
        self.append(client)
        
        # everyone joining a queue is sent the welcome to the chnnel msg        
        welcome_msg = f"[Server message ({get_time()})] Welcome to the " \
            + f"{channel_name} channel, {client.name}."
        message = {
            'message_type': 'basic',
            'message': welcome_msg
        }
        client.send_message(message)
        
        # if there are no spaces in the chat room send the queue position message
        if spaces_in_chat_room == 0:
            queue_message = {
                'message_type': 'basic',
                'message': f"[Server message ({get_time()})] You are in the "
                    + f"waiting queue and there are {len(self) - 1} user(s) ahead of you."
            }
            client.send_message(queue_message)
            
        self.lock.release()
        
        
    def get(self) -> ServerClient:
        """
        Removes and returns the client at the start of the queue.

        Returns:
            ServerClient: The client at the start of the queue. None if the queue is empty 
        """
        self.lock.acquire()
        if len(self) == 0:
            return None
        user: ServerClient = self.pop(0)
        self.send_waiting_queue_location_message()
        self.lock.release()
        return user
        
        
    def remove_client(self, client: ServerClient) -> None:
        """
        Removes the given user from the queue.
        
        The user provided can be at any location in the queue.

        Args:
            client (ServerClient): the client to remove from the queue 
        """
        self.lock.acquire()
        self.remove(client)
        self.send_waiting_queue_location_message()
        self.lock.release()

    
    def send_waiting_queue_location_message(self) -> None:
        """
        Sends the location message to all clients in the queue.
        """
        for i, user in enumerate(self):
            user_location = i
            queue_loc_msg = f"[Server message ({get_time()})] You are in the" \
                + f" waiting queue and there are {user_location} user(s)" \
                + " ahead of you."
            
            message = {
                'message_type': 'basic',
                'message': queue_loc_msg
            }
            user.send_message(message)