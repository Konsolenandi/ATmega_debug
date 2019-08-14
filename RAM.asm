.dseg

ispassed_250ms:
.BYTE 1

UART_TX_P:		; Index of current byte to send via UART
.BYTE 1
UART_TX_LEN:	; Length of current UART transmission
.BYTE 1
UART_TX_BUF:	; Transmit buffer for UART transmissions
.BYTE TXBUF_SIZE
UART_RX_BUF:	; Receive buffer for UART transmissions
.BYTE RXBUF_SIZE

TESTBUF:
.BYTE 6