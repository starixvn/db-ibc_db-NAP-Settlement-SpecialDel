WAITFOR DELAY '00:00:00.500'
DECLARE @SBDialog_NG uniqueidentifier
DECLARE @SBDialog_VSSoccer uniqueidentifier
DECLARE @Message NVARCHAR(128)

SET @SBDialog_NG = '439B039F-12D8-E811-8DD0-782BCB4F7604'
-- Send messages on Dialog

DECLARE @start INT = 1, @End INT = 30

WHILE @start <=@End
BEGIN
	WAITFOR DELAY '00:00:00.800'
	-- Send messages on Dialog
	SET @Message = N'Hello, I am Number Game 2';
	SEND ON CONVERSATION @SBDialog_NG
	MESSAGE TYPE MessageType_Settlement_OtherSports (@Message)

	SET @start = @start + 1
	
	WAITFOR DELAY '00:00:00:200'
END	
