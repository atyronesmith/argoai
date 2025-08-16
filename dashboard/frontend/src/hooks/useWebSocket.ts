import { useEffect, useRef, useState } from 'react';

interface WebSocketHook {
  isConnected: boolean;
  sendMessage: (message: any) => void;
  lastMessage: any;
}

export const useWebSocket = (url: string, onMessage?: (data: any) => void): WebSocketHook => {
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<any>(null);
  const ws = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const connectCountRef = useRef(0);

  useEffect(() => {
    console.log('[WebSocket] useWebSocket effect triggered, url:', url);

    const connect = () => {
      connectCountRef.current++;
      console.log(`[WebSocket] Connect attempt #${connectCountRef.current} starting...`);

      try {
        console.log('[WebSocket] Creating new WebSocket instance for URL:', url);
        ws.current = new WebSocket(url);
        console.log('[WebSocket] WebSocket instance created, readyState:', ws.current.readyState);

        ws.current.onopen = () => {
          console.log('[WebSocket] onopen fired, readyState:', ws.current?.readyState);
          console.log('[WebSocket] WebSocket connected successfully');
          setIsConnected(true);

          // Ensure WebSocket is fully open before sending
          if (ws.current?.readyState === WebSocket.OPEN) {
            console.log('[WebSocket] Sending subscribe message immediately');
            ws.current.send(JSON.stringify({ type: 'subscribe' }));
          } else {
            console.log('[WebSocket] WebSocket not fully open yet, scheduling retry...');
            // If not fully open yet, wait a bit and retry
            setTimeout(() => {
              console.log('[WebSocket] Retry: readyState is', ws.current?.readyState);
              if (ws.current?.readyState === WebSocket.OPEN) {
                console.log('[WebSocket] Sending subscribe message after delay');
                ws.current.send(JSON.stringify({ type: 'subscribe' }));
              } else {
                console.log('[WebSocket] Failed to send subscribe - WebSocket not open');
              }
            }, 100);
          }
        };

        ws.current.onmessage = (event) => {
          console.log('[WebSocket] Message received:', event.data);
          try {
            const data = JSON.parse(event.data);
            console.log('[WebSocket] Parsed message:', data);
            setLastMessage(data);
            onMessage?.(data);
          } catch (error) {
            console.error('[WebSocket] Error parsing message:', error);
          }
        };

        ws.current.onclose = (event) => {
          console.log('[WebSocket] onclose fired, code:', event.code, 'reason:', event.reason, 'wasClean:', event.wasClean);
          console.log('[WebSocket] WebSocket disconnected');
          setIsConnected(false);

          // Clear any existing reconnect timeout
          if (reconnectTimeoutRef.current) {
            clearTimeout(reconnectTimeoutRef.current);
          }

          // Attempt to reconnect after 3 seconds
          console.log('[WebSocket] Scheduling reconnect in 3 seconds...');
          reconnectTimeoutRef.current = setTimeout(() => {
            console.log('[WebSocket] Reconnecting...');
            connect();
          }, 3000);
        };

        ws.current.onerror = (error) => {
          console.error('[WebSocket] onerror fired:', error);
          console.error('[WebSocket] Error details:', {
            readyState: ws.current?.readyState,
            url: ws.current?.url,
            protocol: ws.current?.protocol,
            extensions: ws.current?.extensions
          });
          setIsConnected(false);
        };
      } catch (error) {
        console.error('[WebSocket] Failed to create WebSocket connection:', error);
        setTimeout(connect, 3000);
      }
    };

    connect();

    return () => {
      console.log('[WebSocket] Cleanup function called');
      console.log('[WebSocket] Current WebSocket state:', ws.current?.readyState);

      // Clear reconnect timeout
      if (reconnectTimeoutRef.current) {
        console.log('[WebSocket] Clearing reconnect timeout');
        clearTimeout(reconnectTimeoutRef.current);
      }

      // Close WebSocket if open
      if (ws.current) {
        console.log('[WebSocket] Closing WebSocket connection');
        ws.current.close();
      }
    };
  }, [url, onMessage]);

  const sendMessage = (message: any) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(message));
    }
  };

  return { isConnected, sendMessage, lastMessage };
};