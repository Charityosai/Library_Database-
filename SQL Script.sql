
---CREATE A DATABASE CALLED LibraryManagement----
CREATE DATABASE LibraryManagement;

---CREATING THE TABLES---
----CREATE Address TABLE----
CREATE TABLE Address (
   AddressID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
   Address_1 NVARCHAR(100)  NOT NULL,
   Address_2 NVARCHAR(50)  NULL,
   City NVARCHAR(50)  NOT NULL,
   Postcode NVARCHAR(20)  NOT NULL,
   CONSTRAINT UC_Address UNIQUE (Address_1, Postcode)
);



----CREATE LibraryMembership TABLE----
CREATE TABLE LibraryMembership (
   MembershipID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
   FirstName NVARCHAR(100) NOT NULL,
   LastName NVARCHAR(100) NOT NULL,
   UserName NVARCHAR(50) NOT NULL UNIQUE,
   DateOfBirth DATE NOT NULL,
   AddressID INT NOT NULL,
   Email NVARCHAR(100) UNIQUE NULL,
   PhoneNo NVARCHAR(50) UNIQUE NULL,
   MembershipStartDate DATE DEFAULT(GETDATE()) NOT NULL,
   MembershipStatus NVARCHAR(20) DEFAULT('Active'),
   MembershipEndDate DATE NULL,
   PasswordHash BINARY(64) NOT NULL,
   PasswordSalt UNIQUEIDENTIFIER,
   CONSTRAINT CK_MembershipStatus CHECK (MembershipStatus IN ('Active', 'Inactive')),
   CONSTRAINT CK_Email CHECK (Email LIKE '%_@_%._%'),
   CONSTRAINT FK_Address FOREIGN KEY (AddressID) REFERENCES Address(AddressID),
   CONSTRAINT CK_UserName CHECK (LEN(UserName) >= 5), 
   CONSTRAINT CK_Password CHECK (LEN(PasswordHash) >= 8 AND PasswordHash LIKE '%[A-Z]%' AND PasswordHash LIKE '%[a-z]%' AND PasswordHash LIKE '%[0-9]%')
);



----CREATE ItemType TABLE----
CREATE TABLE ItemType (
ItemTypeID TINYINT IDENTITY(1,1) PRIMARY KEY NOT NULL,
ItemType NVARCHAR(20) UNIQUE NOT NULL
);

----CREATE Author TABLE----
CREATE TABLE Author(
AuthorID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
AuthorFirstName NVARCHAR(100) NOT NULL,
AuthorLastName NVARCHAR(100) NOT NULL, 
CONSTRAINT UQ_Author UNIQUE (AuthorFirstName, AuthorLastName)
);



----CREATE LibraryCatalogue TABLE----
CREATE TABLE LibraryCatalogue (
  CatalogueNumber INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
  ItemTitle NVARCHAR(225) NOT NULL,
  ItemTypeID TINYINT NOT NULL,
  AuthorID INT NOT NULL,
  YearOfPublication INT NOT NULL,
  ISBN NVARCHAR(50) NULL,
  NumberofCopies INT NOT NULL,
  CONSTRAINT CK_NumberofCopies CHECK (NumberofCopies >= 0),
  CONSTRAINT FK_ItemTypeID FOREIGN KEY (ItemTypeID) REFERENCES ItemType(ItemTypeID),
  CONSTRAINT FK_Author FOREIGN KEY (AuthorID) REFERENCES Author(AuthorID)
);



----CREATE LibraryInventory TABLE----
CREATE TABLE LibraryInventory (
InventoryID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
CatalogueNumber INT NOT NULL, 
CurrentStatus NVARCHAR(20) NOT NULL, 
DateAdded DATE NOT NULL,
DateRemoved DATE NULL, 
CONSTRAINT CK_CurrentStatus CHECK (CurrentStatus IN ('overdue', 'On loan', 'removed', 'lost', 'available')),
CONSTRAINT FK_CatalogueNumber FOREIGN KEY (CatalogueNumber) REFERENCES LibraryCatalogue (CatalogueNumber)
);


----CREATE LoanRecords TABLE----
CREATE TABLE LoanRecords(
MembershipID INT NOT NULL,
LoanID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
InventoryID INT NOT NULL,
LoanRequestDate DATE NOT NULL,
DueDate DATE NOT NULL,
ReturnDate DATE NULL,
CONSTRAINT FK_InventoryID FOREIGN KEY (InventoryID) REFERENCES LibraryInventory (InventoryID),
CONSTRAINT FK_MembershipID FOREIGN KEY (MembershipID) REFERENCES LibraryMembership (MembershipID)
);


----CREATE OverdueFines TABLE----
CREATE TABLE OverdueFines(
LoanID INT PRIMARY KEY NOT NULL,
MembershipID INT NOT NULL,
NumberofDaysOverdue INT NOT NULL,
OverdueFines DECIMAL(10,2) NOT NULL,
OutstandingBalance DECIMAL(10,2) NOT NULL, 
CONSTRAINT FK_LoanID FOREIGN KEY (LoanID) REFERENCES LoanRecords (LoanID),
CONSTRAINT FK_Overdue_Member FOREIGN KEY (MembershipID) REFERENCES LibraryMembership (MembershipID)
);


----CREATE OverdueFinesRepayment TABLE----
CREATE TABLE OverdueFineRepayment (
RepaymentID INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
LoanID INT NOT NULL, 
RepaymentMethod NVARCHAR(20)  NOT NULL, 
RepaymentAmount DECIMAL(10,2)  NOT NULL,
RepaymentDate DATETIME2 DEFAULT(GETDATE()) NOT NULL,
CONSTRAINT CK_RepaymentMethod CHECK (RepaymentMethod in ('Cash', 'Card')),
CONSTRAINT FK_LoanID_Overduefines FOREIGN KEY (LoanID) REFERENCES Overduefines (LoanID)
);


---INSERT RECORD INTO ITEMTYPE TABLE----
INSERT INTO ItemType
VALUES ('Book'), ('DVD'), ('Journal'), ('OtherMedia')


-----CREATE AND GRANT PRIVILEDGE TO THE STAFF HEAD(PASCAL STEPHEN)

CREATE LOGIN PASCALSTEPHEN
WITH PASSWORD = 'DJksesty20!';

GRANT SELECT, INSERT, DELETE, UPDATE ON LibraryManagement TO
PASCALSTEPHEN WITH GRANT OPTION;

---CREATING DATABASE OBJECTS
----QUESTION 1
----CREATION OF TABLES

----QUESTION 2(A)
---STORED PROCEDURE TO SEARCH FOR THE TITLE OF AN ITEM---

CREATE PROCEDURE Sp_SearchCatalogueTitle
    @SearchTitle NVARCHAR(255)
AS
BEGIN
	---Search item title column using matching string
    SELECT * FROM LibraryCatalogue
    WHERE ItemTitle LIKE '%' + @SearchTitle + '%'
    ORDER BY YearOfPublication DESC
END

EXEC Sp_SearchCatalogueTitle 'green'
---------------------------------------------------------------

----QUESTION 2(B)

---FUNCTION TO CHECK LOANED ITEMS DUE IN LESS THAN 5DAYS---

CREATE FUNCTION Dbo.LoanItemsDueSoon()
RETURNS TABLE
AS
RETURN (
   SELECT LR.LoanID, LR.MembershipID, LR.InventoryID, LC.ItemTitle, IT.ItemType, LI.CurrentStatus, LR.LoanRequestDate, LR.DueDate, LR.ReturnDate
FROM LoanRecords AS LR
INNER JOIN LibraryInventory AS LI ON LR.InventoryID = LI.InventoryID
INNER JOIN LibraryCatalogue AS LC ON LI.CatalogueNumber = LC.CatalogueNumber
INNER JOIN ItemType AS IT ON LC.ItemTypeID = IT.ItemTypeID
    WHERE LR.ReturnDate IS NULL AND LI.CurrentStatus = 'On Loan' AND DATEDIFF(day, GETDATE(), DueDate) < 5
);


SELECT * from Dbo.LoanItemsDueSoon()

---------------------------------------------------------------
----QUESTION 2(C)

---STORED PROCEDURE TO INSERT NEW LIBRARY MEMBER RECORD---
CREATE PROCEDURE Sp_InsertNewMemberRecord
   @FirstName NVARCHAR(100),
   @LastName NVARCHAR(100),
   @UserName NVARCHAR(50),
   @DateOfBirth DATE,
   @Email NVARCHAR(100),
   @PhoneNo NVARCHAR(50),
   @Address_1 NVARCHAR(100),
   @Address_2 NVARCHAR(50),
   @City NVARCHAR(50),
   @Postcode NVARCHAR(20),
   @PasswordHash NVARCHAR(50)

AS

DECLARE @PasswordSalt UNIQUEIDENTIFIER=NEWID()

BEGIN
    SET NOCOUNT ON;

	---Set explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;
    ---Check if the address already exists in the Address table
    DECLARE @AddressID int;
    SELECT @AddressID = AddressID FROM Address WHERE Address_1 = @Address_1 AND Postcode = @Postcode;

    ---If Address doesn't exist, insert the new record into the Address table
    IF @AddressID IS NULL
    BEGIN
        INSERT INTO Address (Address_1,Address_2,City, Postcode)
        VALUES (@Address_1,@Address_2,@City, @Postcode);
        SET @AddressID = SCOPE_IDENTITY();
    END;

   ---Insert a new record into LibraryMembership table with the corresponding AddressID
INSERT INTO LibraryMembership (
    FirstName,
    LastName,
    DateOfBirth,
    Email,
    PhoneNo,
    AddressID,
    Username,
    PasswordHash,
    PasswordSalt
)
VALUES (
    @FirstName,
    @LastName,
    @DateOfBirth,
    @Email,
    @PhoneNo,
    @AddressID,
    @Username,
    HASHBYTES('SHA2_512', @PasswordHash + CAST(@PasswordSalt AS NVARCHAR(36))),
    @PasswordSalt
);

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END

---Execute stored procedure
EXEC Sp_InsertNewMemberRecord
	@FirstName= 'Charity',
    @LastName = 'Osaigbovo',
    @DateOfBirth = '1979-07-03',
    @Email = 'c.e.osaigbovo@edu.salford.ac.uk',
    @PhoneNo = '985632014782',
    @Address_1 = '149, China Lane',
	@Address_2 =  '',
	@City = 'Bolton',
	@Postcode = 'M11 5ky',
	@Username = 'Charity512',
	@PasswordHash = 'hbnsh@gaj5211'

---------------------------------------------------------------------------------------------
----QUESTION 2(D)

---STORED PROCEDURE TO UPDATE LIBRARY MEMBERP RECORD---
CREATE PROCEDURE Sp_UpdateMemberRecord
  @MembershipID INT,
  @FirstName NVARCHAR(100) = NULL,
  @LastName NVARCHAR(100) = NULL,
  @Email NVARCHAR(100) = NULL,
  @PhoneNo NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

	---Set explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;

---Check if the MembershipID exists in the LibraryMembership table and is active
    IF NOT EXISTS (
        SELECT * FROM LibraryMembership WHERE MembershipID = @MembershipID AND MembershipStatus = 'Active')
    BEGIN
        RAISERROR('Error: Invalid or Inactive MembershipID. Please input a valid/active MembershipID',16, 1);
        RETURN;
    END;

---Update specified member details
	UPDATE LibraryMembership
	SET
		FirstName = COALESCE(@FirstName, FirstName),
		LastName = COALESCE(@LastName, LastName),
		Email = COALESCE(@Email, Email),
		PhoneNo = COALESCE(@PhoneNo, PhoneNo)
	WHERE
		MembershipID = @MembershipID

 ---Display a success message 
    PRINT 'Member record updated successfully';
	
---commit transaction or rollback if any error is encountered
	COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END

EXEC Sp_UpdateMemberRecord 
		@MembershipID = 4, 
		@Email = 'cece@yahoo.com'
-------------------------------------------------------
----QUESTION 3
---VIEW TO VIEW FULL LOAN HISTORY---
CREATE VIEW View_FullLoanHistory
AS
SELECT LR.LoanID, LR.MembershipID, LR.InventoryID, LC.ItemTitle, IT.ItemType, 
LR.LoanRequestDate, LR.DueDate, LR.ReturnDate, OV.OverdueFines, OV.OutstandingBalance
FROM LoanRecords AS LR
LEFT JOIN OverdueFines AS OV ON LR.LoanID = OV.LoanID
INNER JOIN LibraryInventory AS LI ON LR.InventoryID = LI.InventoryID
INNER JOIN LibraryCatalogue AS LC ON LI.CatalogueNumber = LC.CatalogueNumber
INNER JOIN ItemType AS IT ON LC.ItemTypeID = IT.ItemTypeID;

Select * from View_FullLoanHistory

-----------------------------------------------------------
----QUESTION 4
---TRIGGER TO UPDATE STATUS OF RETURNED ITEM TO AVAILABLE---
CREATE TRIGGER Tr_UpdateAvailableStatusForReturnedItem
ON LoanRecords
AFTER UPDATE
AS
BEGIN
	---Check if return date was updated
    IF UPDATE(ReturnDate)
    BEGIN
		---Update the corresponding status to Available on the Library Invventory table
        UPDATE LibraryInventory
        SET CurrentStatus = 'Available'
        FROM LibraryInventory LI
        JOIN Inserted I ON LI.InventoryID = I.InventoryID
        WHERE I.ReturnDate IS NOT NULL;
    END
END
----------------------------------------------
----QUESTION 5
----FUNCTION TO RETURN TOTAL NUMBER OF LOANS MADE ON A SPECIFIED DATE---
CREATE FUNCTION Dbo.TotalLoanCountPerDate (@LoanRequestDate DATE)
RETURNS INT
AS
BEGIN
    DECLARE @TotalLoanCount INT

	---Count the number of Loans issued on the specified date
    SELECT @TotalLoanCount = COUNT(*)
    FROM LoanRecords
    WHERE LoanRequestDate = @LoanRequestDate

    RETURN @TotalLoanCount
END

---Call the function to return the result
SELECT Dbo.TotalLoanCountPerDate ('2023-04-22')

------------------------------------------------------------
----QUESTION 6(A)

---STORED PROCEDURE TO INSERT NEW LIBRARY CATALOGUE ITEM---
CREATE PROCEDURE Sp_InsertNewLibraryCatalogueItem
    @ItemTitle NVARCHAR(100),
    @ItemTypeID TINYINT,
    @YearOfPublication INT,
    @ISBN NVARCHAR(50),
    @NumberofCopies INT,
    @AuthorFirstName NVARCHAR(100),
    @AuthorLastName NVARCHAR(100)
AS
BEGIN
	---Turn off number of affected rows
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        ---Check if the author already exists
        DECLARE @AuthorID INT;

		SELECT @AuthorID = AuthorID FROM Author WHERE AuthorFirstName = @AuthorFirstName AND AuthorLastName = @AuthorLastName;

        IF @AuthorID IS NULL
        BEGIN
        ---Insert new Author record
            INSERT INTO Author (AuthorFirstName, AuthorLastName)
            VALUES (@AuthorFirstName, @AuthorLastName);
            SET @AuthorID = SCOPE_IDENTITY();
        END;

        ---Check if the record already exists in the LibraryCatalogue table
        IF EXISTS (
            SELECT * FROM LibraryCatalogue WHERE ItemTitle = @ItemTitle AND ItemTypeID = @ItemTypeID AND AuthorID = @AuthorID
        )
        BEGIN
			---Return error if item already exist in the Library Catalogue table
            RAISERROR ('Error: Item already exists in the Library Catalogue.
			For new supplies, update the Library Inventory record for this item.', 16, 1);
            RETURN;
        END;

		---check if ISBN has been inputted for book type
		IF (@ItemTypeID = 1 AND @ISBN IS NULL)
        BEGIN
            ---Return error if item type is book and ISBN is not provided
            RAISERROR ('Error: ISBN is required for books.', 16, 1);
            RETURN;
        END;

		---check that ISBN has not been inputted for other item types
		IF (@ItemTypeID <> 1 AND @ISBN IS NOT NULL)
        BEGIN
            ---Return error if item type is book and ISBN is not provided
            RAISERROR ('ISBN is only required for books.', 16, 1);
            RETURN;
        END;

        -- Insert new library catalogue item with the assigned author ID 
        DECLARE @CatalogueNumber INT;
        INSERT INTO LibraryCatalogue (ItemTitle, ItemTypeID, AuthorID, YearOfPublication, ISBN, NumberofCopies)
        VALUES (@ItemTitle, @ItemTypeID, @AuthorID, @YearOfPublication, @ISBN, @NumberofCopies);
        SET @CatalogueNumber = SCOPE_IDENTITY();

        -- Insert new inventory records for each copy of the item
        DECLARE @i INT = 1;
        WHILE (@i <= @NumberofCopies)
        BEGIN
            INSERT INTO LibraryInventory (CatalogueNumber, DateAdded, CurrentStatus)
            VALUES (@CatalogueNumber, GETDATE(), 'Available');
            SET @i += 1;
        END;
---commit transaction or rollback if any error is encountered
 COMMIT TRANSACTION;
 END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

EXEC  Sp_InsertNewLibraryCatalogueItem 
		@ItemTitle = 'Beyond statistics',
        @ItemTypeID = 3,
        @YearOfPublication = 2021,
        @ISBN = NULL,
        @NumberofCopies = 3,
		@AuthorFirstName = 'Weslie',
		@AuthorLastName = 'James'


-------------------------------------------------------------
----QUESTION 6(B)

---STORED PROCEDURE TO INSERT NEW INVENTORY ITEM---
CREATE PROCEDURE Sp_InsertNewInventoryRecord
	 @CatalogueNumber INT,
	 @NumberOfCopies INT
AS
BEGIN
SET NOCOUNT ON;

---Set explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;

	---Loop to insert the specified number of records into the Library inventory table
    DECLARE @i INT = 1
    WHILE (@i <= @NumberOfCopies)
    BEGIN
        DECLARE @InventoryId INT
        SET @InventoryId = (SELECT MAX(InventoryId) + 1 FROM LibraryInventory)

        INSERT INTO LibraryInventory (CatalogueNumber, DateAdded, CurrentStatus)
        VALUES ( @CatalogueNumber, GETDATE(), 'Available')

        SET @i = @i + 1
    END
	---Increase the number of copies for the item on Library catalogue table
    UPDATE LibraryCatalogue
    SET NumberOfCopies = NumberOfCopies + @NumberOfCopies where CatalogueNumber = @CatalogueNumber
  
    ---Display a message indicating that the update was successful
	PRINT 'Record updated successfully'

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END

---Execute stored procedure
EXEC Sp_InsertNewInventoryRecord
	@CatalogueNumber = 50,
	@NumberOfCopies = 2
---------------------------------------------------------------
----QUESTION 6(C)

---STORED PROCEDURE TO INSERT NEW LOAN RECORD---
CREATE PROCEDURE Sp_NewLoanRecord
    @MembershipID INT,
    @InventoryID INT
    
AS
BEGIN
SET NOCOUNT ON;

	---Set explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;

	---Check if InventoryID is valid
    IF NOT EXISTS (SELECT * FROM LibraryInventory WHERE InventoryID = @InventoryID)
    BEGIN
		---Throw error if InventoryID is not valid
        RAISERROR('Invalid InventoryID.', 16, 1)
        RETURN
    END

	---Check if MembershipID is valid
    IF NOT EXISTS (SELECT * FROM LibraryMembership WHERE MembershipID = @MembershipID and MembershipStatus = 'Active')
    BEGIN
        ---Throw error if MembershipID is not valid
        RAISERROR('Invalid/Inactive MembershipID.', 16, 1)
        RETURN
    END
	  
	  ---Check if item is already on loan
    IF EXISTS (SELECT * FROM LibraryInventory WHERE InventoryID = @InventoryID AND CurrentStatus != 'Available')
    BEGIN
		---Throw error if already on loan
        RAISERROR('Item is already Unavailable.', 16, 1)
        RETURN
    END

	---Insert new loan record 
    INSERT INTO LoanRecords (MembershipID, InventoryID, LoanRequestDate, DueDate)
    VALUES (@MembershipID, @InventoryID, GETDATE(), DATEADD(DAY, 7, GETDATE()))

	---Update the status on library Inventory
    UPDATE LibraryInventory SET CurrentStatus = 'On Loan' WHERE InventoryID = @InventoryID

	PRINT 'Loan Request successful'

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

END;

drop procedure Sp_NewLoanRecord

---Execute stored procedure
EXEC Sp_NewLoanRecord
	@MembershipID = 4,
    @InventoryID = 37
----------------------------------------------------------
----QUESTION 6(D)

---STORED PROCEDURE TO MAKE AN OVERDUE FINE REPAYMENT---
CREATE PROCEDURE Sp_OverdueFineRepayment
    @LoanID int,
    @RepaymentMethod nvarchar(20),
    @RepaymentAmount decimal(10,2)
AS
BEGIN
SET NOCOUNT ON;

---Set explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;

DECLARE @OverdueFines decimal(10,2);
DECLARE @OutstandingBalance decimal(10,2);

IF NOT EXISTS (SELECT 1 FROM LoanRecords WHERE LoanID = @LoanID)
BEGIN
    ---Display error if LoanID is not valid
	RAISERROR('Error: LoanID is not valid.', 16, 1)
	RETURN;
END;

---Check that item has been returned
IF EXISTS (SELECT 1 FROM LoanRecords WHERE LoanID = @LoanID and ReturnDate IS NULL)
    BEGIN
	RAISERROR('Please return item before making a repayment.', 16, 1)
	RETURN;
END;

BEGIN
    ---Get the current OutstandingBalance from OverdueFines table
    SELECT @OutstandingBalance = OutstandingBalance
    FROM OverdueFines
    WHERE LoanID = @LoanID;

    ---Check if repayment amount is greater than the OutstandingBalance
    IF (@RepaymentAmount > @OutstandingBalance)
    BEGIN

    ---Display error if repayment amount is greater
	RAISERROR('Error: Repayment amount cannot be greater than Overdue fine.', 16, 1)
	RETURN;
END;
    
    ---Calculate the new OverdueBalance
    SET @OutstandingBalance = @OutstandingBalance - @RepaymentAmount;
END;
BEGIN
	---Insert the new repayment record
	INSERT INTO OverdueFineRepayment (LoanID, RepaymentMethod, RepaymentAmount, RepaymentDate)
	VALUES (@LoanID, @RepaymentMethod, @RepaymentAmount, GETDATE());

	---Update the OutstandingBalance in the OverdueFines table
	UPDATE OverdueFines
	SET OutstandingBalance = @OutstandingBalance
	WHERE LoanID = @LoanID;

	---Display repayment success message
	PRINT 'Repayment successful'
END;

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

END

---Execute stored procedure
EXEC Sp_OverdueFineRepayment
	@LoanID = 11,
	@RepaymentMethod = 'cash',
	@RepaymentAmount = 0.5


------------------------------------------------------------------------------

----QUESTION 6(E)

---TRIGGER TO INSERT A NEW OVERDUE FINE RECORD---
CREATE TRIGGER Tr_InsertNewOverdueFine
ON LoanRecords
AFTER INSERT, UPDATE
AS
BEGIN
    IF GETDATE() > (SELECT DueDate FROM inserted)
    BEGIN
		---Insert new overdue fine record to overduefines table
        INSERT INTO OverdueFines (LoanID, MembershipID, NumberofDaysOverdue, OverdueFines, OutstandingBalance)
        SELECT  LoanID, MembershipID, DATEDIFF(day, DueDate, GETDATE()) AS NumberofDaysOverdue, (DATEDIFF(day, DueDate, GETDATE()) * 0.1) AS OverdueFines, (DATEDIFF(day, DueDate, GETDATE()) * 0.1) AS OverdueBalanceRemaining
        FROM inserted
        WHERE ReturnDate IS NULL

		---Update the status on library Inventory table to overdue
		UPDATE LibraryInventory SET CurrentStatus = 'Overdue' WHERE InventoryID IN (SELECT I.InventoryID FROM Inserted I INNER JOIN 
		LoanRecords LR on I.loanid = LR.loanid)
    END;
END;

-------------------------------------------------------
----QUESTION 7(A)

---STORED PROCEDURE TO RETURN A LOANED ITEM---
CREATE PROCEDURE Sp_ReturnItem
    @LoanID int
   
AS
BEGIN
SET NOCOUNT ON;

---Create explicit transaction
BEGIN TRY
	BEGIN TRANSACTION;

	---Check if record exist and has not been returned
	IF NOT EXISTS (
        SELECT * FROM LoanRecords WHERE LoanID = @LoanID AND ReturnDate IS NULL
    )
    BEGIN
	---Throw error if loan record does not exist or return date is already updated
        RAISERROR('Invalid request: Item is not On Loan.', 16, 1)
        RETURN;
    END;

    ---Update return date on LoanRecords table
    UPDATE LoanRecords
    SET ReturnDate = GETDATE()
    WHERE LoanID = @LoanID;

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
END TRY
	BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
	END CATCH;

END;

---Execute stored procedure
EXEC Sp_ReturnItem
	@LoanID = 11
--------------------------------------------------------
----QUESTION 7(B)

----STORED PROCEDURE TO UPDATE LOST OR REMOVED ITEMS----
CREATE PROCEDURE Sp_UpdateLost_RemovedItem
    @InventoryID  INT,
    @CurrentStatus NVARCHAR(20)
AS
BEGIN
SET NOCOUNT ON;

---Set explicit transaction
BEGIN TRY
BEGIN TRANSACTION;

	DECLARE @NumberOfCopies INT
	DECLARE @CatalogueNumber INT

    --Check if InventoryId exist on the inventory table
    IF NOT EXISTS (SELECT 1 FROM LibraryInventory WHERE InventoryID = @InventoryID)
    BEGIN
		---return error if no record is found for the inventoryID specified
        RAISERROR ('Error: InventoryID does not exist', 16, 1)
        RETURN;
    END;

	---Check if currentstatus of the item is already on lost/removed
	IF EXISTS (SELECT * FROM LibraryInventory WHERE CurrentStatus IN ('removed', 'lost') and InventoryID = @InventoryID)
    BEGIN
		---Return error if item status is already on lost/removed
        RAISERROR ('Item is already removed or lost', 16, 1)
        RETURN;
    END;

    ---Update the currentstatus to lost/removed
    UPDATE LibraryInventory
    SET CurrentStatus = @CurrentStatus, DateRemoved = GETDATE()
    WHERE InventoryID = @InventoryID

    ---Retrieve the number of copies for the item
    SELECT @NumberOfCopies = NumberofCopies
    FROM LibraryCatalogue
    WHERE @CatalogueNumber = (select CatalogueNumber FROM LibraryInventory WHERE InventoryID = @InventoryID)

	---Reduce the number of copies by 1 
	 UPDATE LibraryCatalogue
        SET NumberofCopies = @NumberofCopies - 1
        WHERE CatalogueNumber = @CatalogueNumber

    ---Display success message
    PRINT 'Record updated successfully'

---commit transaction or rollback if any error is encountered
COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END

EXEC Sp_UpdateLost_RemovedItem
@InventoryID = 33,
@CurrentStatus = 'lost'


----------------------------------------------------------
----QUESTION 7(C)
---STORED PROCEDURE TO END LIBRARY MEMBERSHIP---
CREATE PROCEDURE Sp_EndLibraryMembership
    @MembershipID INT
AS
BEGIN
    SET NOCOUNT ON;

    ---Check if the MembershipID exists in the LibraryMembership table and is active
     IF NOT EXISTS (
        SELECT * FROM LibraryMembership WHERE MembershipID = @MembershipID AND MembershipStatus = 'Active')
    BEGIN
        RAISERROR('Error: Invalid or Inactive MembershipID. Please input a valid/active MembershipID',16, 1);
        RETURN;
 END;
 ---Update the MembershipStatus and MembershipEndDate for the specified MembershipID
    UPDATE LibraryMembership
    SET MembershipStatus = 'Inactive', MembershipEndDate = GETDATE()
    WHERE MembershipID = @MembershipID;

    ---Display success message
    PRINT 'Library membership ended successfully';
	
END

---Execute stored procedure
EXEC Sp_EndLibraryMembership 
	@MembershipID = 7;
----------------------------------------------------------------------------------`
----QUESTION 7(D)

---STORED PROCEDURE TO REACTIVATE LIBRARY MEMBERSHIP---

CREATE PROCEDURE Sp_ReactivateLibraryMembership
    @MembershipID INT
AS
BEGIN
    SET NOCOUNT ON;

     IF NOT EXISTS (
        SELECT * FROM LibraryMembership WHERE MembershipID = @MembershipID AND MembershipStatus = 'Inactive')
    BEGIN
        RAISERROR('Error: Invalid or Inactive MembershipID. Please input a valid/active MembershipID',16, 1);
        RETURN;
    END;
    
        UPDATE LibraryMembership SET MembershipStatus = 'Active', MembershipEndDate = NULL WHERE MembershipID = @MembershipID;
        PRINT 'Membership reactivated successfully.';
    
END

---Execute stored procedure
EXEC Sp_ReactivateLibraryMembership 
	@MembershipID = 4;
------------------------------------------------------------------------------

---QUESTION 7(E)

---VIEW TO VIEW RECORD OF ALL LOST/REMOVED ITEMS---
CREATE VIEW View_LostOrRemovedItems AS
SELECT LI.InventoryID, LC.ItemTitle, A.AuthorFirstName + ' ' + A.AuthorLastName as Author, 
IT.ItemType, LC.ISBN, LI.CurrentStatus, LI.DateAdded, LI.DateRemoved
FROM LibraryCatalogue LC
INNER JOIN ItemType IT ON LC.ItemTypeID = IT.ItemTypeID
INNER JOIN Author A ON LC.AuthorID = A.AuthorID
INNER JOIN LibraryInventory LI ON LC.CatalogueNumber = LI.CatalogueNumber
WHERE LI.CurrentStatus IN ('Lost', 'Removed');

SELECT * FROM View_LostOrRemovedItems

-----------------------------------------------

----QUESTION 7(F)

---VIEW TO VIEW THE CURRENT STATUS OF AN ITEM---
SELECT * FROM LibraryInventory where InventoryID = 5
-----------------------------------------
---QUESTION(G)
---VIEW TO SEE A RECORD OF ALL INACTIVE MEMBERS
CREATE VIEW View_InactiveMembers AS
SELECT * FROM LibraryMembership 
WHERE Membershipstatus = 'Inactive'

-------------------------------------------
---JOB TO UPDATE NUMBER OF DAYS OVERDUE  AND OVERDUEFINES DAILY
UPDATE OVERDUEFINES SET NumberofDaysOverdue = DATEDIFF(day, DueDate, GETDATE()), OVERDUEFINES = DATEDIFF(day, DueDate, GETDATE()) * 0.1, 
OutstandingBalance = DATEDIFF(day, DueDate, GETDATE()) * 0.1  
FROM LoanRecords L JOIN OVERDUEFINES O
ON L.LOANID = O.LOANID
WHERE L.returndate IS NULL

---------------------------------------------------------
