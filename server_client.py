import time
import socket
from sender_receiver import SenderReceiver

class ServerClient:
    def __init__(self, name, conn_socket, addr) -> None:
        self.name: str = name # name of the Client
        self.conn_socket: socket = conn_socket # connection to client
        self.addr = addr
        self.time_last_active = time.time() # time client was last active
        self.time_of_mute = 0 # epoch of time client was muted
        self.time_muted = 0 # time client was last muted for
        
        
    def is_muted(self) -> bool:
        """
        Is the client muted.

        Returns:
            bool: True if the client is muted, False otherwise.
        """
        now = time.time()
        if now > self.time_of_mute + self.time_muted:
            return False
        return True
    
    
    def mute(self, time_muted: int) -> None:
        """
        Mutes the client for the time given in seconds.

        Args:
            time_muted (int): time to mute client in seconds
        """
        # add mute time to time_last_active to simulate "pausing" the AFK timer
        self.time_last_active += time_muted
        
        self.time_of_mute = time.time()
        self.time_muted = time_muted
        
        
    def remaining_time_muted(self) -> int:
        """
        Returns the remaining time the client is muted for.

        Returns:
            int: the remaining time the client is muted for.
        """
        return int(self.time_of_mute + self.time_muted - time.time())
        
        
    def send_message(self, message: dict) -> None:
        """
        Sends a message to the client.

        Args:
            message (dict): the message to be sent to the client
        """
        SenderReceiver.send_message(message, self.conn_socket)
        
        
    def receive_message(self) -> dict:
        """
        Received a message from the client.

        Returns:
            dict: the message read from the client
        """
        return SenderReceiver.receive_message(self.conn_socket)


    def shutdown(self, graceful_shutdown: bool) -> None:
        """
        Shuts down the client.
        
        If graceful_shutdown is true the client is sent a message to allow them
        to shutdown gracefully.
        
        If graceful_shutdown is false the client connection is simply closed
        without warning the client on the other end
        
        A shutdown message is sent to the client then the socket is closed.
        
        Reference:
        [3]     J. Baker, "socket.shutdown vs socket.close" stackoverflow.com. 
        https://stackoverflow.com/questions/409783/socket-shutdown-vs-socket-close 
        (accessed March 29, 2023).
        """
        if graceful_shutdown == True:
            # craft and send shutdown message to client
            shutdown_msg = {
                "message_type": "command",
                "command": "/shutdown"
            }
            self.send_message(shutdown_msg)
        
        # close socket
        self.close_connection()
        
        
    def close_connection(self) -> None:
        """
        Closes connection to client not gracefully.
        """
        try:
            self.conn_socket.shutdown(socket.SHUT_RDWR)
            self.conn_socket.close()
        except OSError as e:
            pass
            
            
    def switch_channel(self, args: list) -> None:
        """
        Switches the channel the client is connected to.
        
        Sends message to client to reconnect on new channel and closes current 
        connection.

        Args:
            args (list): command line arguments provided with switch
        """
        # craft and send reconnect message to client
        reconnect_msg = {
            "message_type": "command",
            "command": "/switch",
            "args": args
        }
        self.send_message(reconnect_msg)
        
        # close the existing socket connection to client
        try:
            self.conn_socket.shutdown(socket.SHUT_RDWR)
            self.conn_socket.close()
        except OSError as e:
            # print(f"OSError: Client connection may have already been closed: {e}", flush=True) # TODO
            return