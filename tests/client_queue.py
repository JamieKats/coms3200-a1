import threading
from utils import get_time
from server_client import ServerClient

class ClientQueue(list):
    """
    A thread safe FIFO queue to store clients in that allows removal at any 
    point in the queue.
    """
    def __init__(self) -> None:
        super().__init__()
        self.lock: threading.Lock = threading.Lock()
        
        
    def put(self, client: ServerClient) -> None:
        """
        Adds the client to the end of the queue in a threadsafe way.

        Args:
            user (ServerClient): client to be added to the queue
        """
        self.lock.acquire()
        self.append(client)
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