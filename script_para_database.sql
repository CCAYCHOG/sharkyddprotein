-- BASE DE DATOS Y TABLAS
CREATE DATABASE Tienda;
GO

USE Tienda;
GO

-- Clientes
CREATE TABLE Clientes (
    ClienteID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    Apellido NVARCHAR(100) NOT NULL,
    Email NVARCHAR(150) UNIQUE,
    Telefono NVARCHAR(20),
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Estado BIT DEFAULT 1 -- 1: Activo, 0: Inactivo (eliminado lógicamente)
);

-- Productos
CREATE TABLE Productos (
    ProductoID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(255),
    Precio DECIMAL(10,2) NOT NULL,
    Stock INT NOT NULL,
    Activo BIT DEFAULT 1
);

-- Pedidos
CREATE TABLE Pedidos (
    PedidoID INT IDENTITY(1,1) PRIMARY KEY,
    ClienteID INT NOT NULL,
    FechaPedido DATETIME DEFAULT GETDATE(),
    Estado NVARCHAR(50) DEFAULT 'Pendiente',  -- Pendiente, Confirmado, Cancelado, Eliminado
    Observaciones NVARCHAR(255),
    FOREIGN KEY (ClienteID) REFERENCES Clientes(ClienteID)
);

CREATE TABLE DetallePedido (
    DetallePedidoID INT IDENTITY(1,1) PRIMARY KEY,
    PedidoID INT NOT NULL,
    ProductoID INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    Subtotal AS (Cantidad * PrecioUnitario) PERSISTED,
    FOREIGN KEY (PedidoID) REFERENCES Pedidos(PedidoID),
    FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID)
);

-- Ventas
CREATE TABLE Ventas (
    VentaID INT IDENTITY(1,1) PRIMARY KEY,
    PedidoID INT UNIQUE NOT NULL,
    FechaVenta DATETIME DEFAULT GETDATE(),
    Total DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (PedidoID) REFERENCES Pedidos(PedidoID)
);

-- Tipos de pago
CREATE TABLE TiposPago (
    TipoPagoID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(50) NOT NULL
);

-- Métodos de pago
CREATE TABLE MetodosPago (
    MetodoPagoID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(50) NOT NULL
);

-- Pagos
CREATE TABLE Pagos (
    PagoID INT IDENTITY(1,1) PRIMARY KEY,
    VentaID INT NOT NULL,
    FechaPago DATETIME DEFAULT GETDATE(),
    MontoPagado DECIMAL(10,2) NOT NULL,
    TipoPagoID INT NOT NULL,
    MetodoPagoID INT NOT NULL,
    Referencia NVARCHAR(100),
    Observaciones NVARCHAR(255),
    FOREIGN KEY (VentaID) REFERENCES Ventas(VentaID),
    FOREIGN KEY (TipoPagoID) REFERENCES TiposPago(TipoPagoID),
    FOREIGN KEY (MetodoPagoID) REFERENCES MetodosPago(MetodoPagoID)
);

-- Insertar cliente
CREATE PROCEDURE sp_InsertarCliente
    @Nombre NVARCHAR(100),
    @Apellido NVARCHAR(100),
    @Email NVARCHAR(150),
    @Telefono NVARCHAR(20)
AS
BEGIN
    INSERT INTO Clientes (Nombre, Apellido, Email, Telefono)
    VALUES (@Nombre, @Apellido, @Email, @Telefono)
END

-- Actualizar cliente
CREATE PROCEDURE sp_ActualizarCliente
    @ClienteID INT,
    @Nombre NVARCHAR(100),
    @Apellido NVARCHAR(100),
    @Email NVARCHAR(150),
    @Telefono NVARCHAR(20)
AS
BEGIN
    UPDATE Clientes
    SET Nombre = @Nombre, Apellido = @Apellido, Email = @Email, Telefono = @Telefono
    WHERE ClienteID = @ClienteID
END

-- Eliminar cliente (lógicamente)
CREATE PROCEDURE sp_EliminarCliente
    @ClienteID INT
AS
BEGIN
    UPDATE Clientes
    SET Estado = 0
    WHERE ClienteID = @ClienteID
END

-- Insertar pedido
CREATE PROCEDURE sp_InsertarPedido
    @ClienteID INT,
    @Observaciones NVARCHAR(255)
AS
BEGIN
    INSERT INTO Pedidos (ClienteID, Observaciones)
    VALUES (@ClienteID, @Observaciones)
END

-- Actualizar pedido
CREATE PROCEDURE sp_ActualizarPedido
    @PedidoID INT,
    @Observaciones NVARCHAR(255)
AS
BEGIN
    UPDATE Pedidos
    SET Observaciones = @Observaciones
    WHERE PedidoID = @PedidoID
END

-- Eliminar pedido (lógicamente)
CREATE PROCEDURE sp_EliminarPedido
    @PedidoID INT
AS
BEGIN
    UPDATE Pedidos
    SET Estado = 'Eliminado'
    WHERE PedidoID = @PedidoID
END

CREATE PROCEDURE sp_ConfirmarPedidoComoVenta
    @PedidoID INT
AS
BEGIN
    DECLARE @Total DECIMAL(10,2)

    IF EXISTS (SELECT 1 FROM Ventas WHERE PedidoID = @PedidoID)
    BEGIN
        RAISERROR('Este pedido ya fue confirmado como venta.', 16, 1)
        RETURN
    END

    SELECT @Total = SUM(Cantidad * PrecioUnitario)
    FROM DetallePedido
    WHERE PedidoID = @PedidoID

    INSERT INTO Ventas (PedidoID, FechaVenta, Total)
    VALUES (@PedidoID, GETDATE(), @Total)

    UPDATE Pedidos
    SET Estado = 'Confirmado'
    WHERE PedidoID = @PedidoID
END

CREATE PROCEDURE sp_RegistrarPago
    @VentaID INT,
    @MontoPagado DECIMAL(10,2),
    @TipoPagoID INT,
    @MetodoPagoID INT,
    @Referencia NVARCHAR(100) = NULL,
    @Observaciones NVARCHAR(255) = NULL
AS
BEGIN
    INSERT INTO Pagos (VentaID, MontoPagado, TipoPagoID, MetodoPagoID, Referencia, Observaciones)
    VALUES (@VentaID, @MontoPagado, @TipoPagoID, @MetodoPagoID, @Referencia, @Observaciones)
END

CREATE PROCEDURE sp_ObtenerSaldoPorVenta
    @VentaID INT = NULL  -- Si se pasa NULL, se listan todas las ventas
AS
BEGIN
    SELECT 
        V.VentaID,
        V.Total AS MontoTotal,
        ISNULL(SUM(P.MontoPagado), 0) AS TotalPagado,
        (V.Total - ISNULL(SUM(P.MontoPagado), 0)) AS SaldoPendiente
    FROM Ventas V
    LEFT JOIN Pagos P ON V.VentaID = P.VentaID
    WHERE (@VentaID IS NULL OR V.VentaID = @VentaID)
    GROUP BY V.VentaID, V.Total
END

CREATE PROCEDURE sp_ListarVentasConSaldoPendiente
AS
BEGIN
    SELECT 
        V.VentaID,
        V.Total AS MontoTotal,
        ISNULL(SUM(P.MontoPagado), 0) AS TotalPagado,
        (V.Total - ISNULL(SUM(P.MontoPagado), 0)) AS SaldoPendiente
    FROM Ventas V
    LEFT JOIN Pagos P ON V.VentaID = P.VentaID
    GROUP BY V.VentaID, V.Total
    HAVING (V.Total - ISNULL(SUM(P.MontoPagado), 0)) > 0
END
