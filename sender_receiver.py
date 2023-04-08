import json
import socket

TCP_MSG_LENGTH_DIGITS = 9

MAX_BUFFER_SIZE = 5


class SenderReceiver:
    
    @staticmethod
    def send_message(message: dict, conn_socket: socket) -> None:
        """
        Send encoded message length then send the message after

        Args:
            message (dict): _description_
        """
        encoded_message = json.dumps(message).encode()
        encoded_message_len = len(encoded_message)
        encoded_message_len = f"{encoded_message_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()

        conn_socket.send(encoded_message_len)
        conn_socket.send(encoded_message)
        
    @staticmethod
    def receive_message(conn_socket: socket) -> dict:
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None
        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        bytes_read = 0
        message = ''
        
        while bytes_read < msg_length:
            # print("received a msg chunk")
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            encoded_message = conn_socket.recv(buffer_size)
            message += encoded_message.decode()
            bytes_read += buffer_size
            
        message = json.loads(message)
        return message
                
            