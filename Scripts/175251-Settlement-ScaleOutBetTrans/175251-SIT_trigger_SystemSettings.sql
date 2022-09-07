/*info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20220907@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220907@Louisa: Create trigger on SIT to capture action lock parlay on SystemSettings [Redmine:#175251]

	Param's Explanation: 
		Run on SIT environment only
*/

USE [bodb02]
GO

--Step 1: create table
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = 'Settlement_Tracking175251')
BEGIN
	CREATE TABLE Settlement_Tracking175251 (
		id	INT IDENTITY(1,1) PRIMARY KEY
		,IP	VARCHAR(20)
		,username VARCHAR(100)
		,dtime DATETIME 
		,sqltext VARCHAR(MAX)
		,hostname VARCHAR(100)
		,VValue VARCHAR(1)
	)
END
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.indexes WHERE name = 'IX_dtime_Settlement_Tracking175251' )
BEGIN
	CREATE NONCLUSTERED INDEX [IX_dtime_Settlement_Tracking175251] ON [dbo].[Settlement_Tracking175251] ( dtime )
END
GO

--step 2: create Trigger
CREATE OR ALTER TRIGGER [dbo].[trg_Udp_SystemSettings] ON [dbo].[SystemSettings] 
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;   
	 
	DECLARE  @str NVARCHAR(100)
			,@hostname VARCHAR(100)
			,@IP NVARCHAR(50)
			,@VValue VARCHAR(1)

	DECLARE @tmp TABLE (eventtype VARCHAR(100), parameter VARCHAR(20),sqltext NVARCHAR(MAX))	
	
	IF EXISTS ( SELECT TOP 1 1  FROM INSERTED i
					INNER JOIN  DELETED d ON i.VName = d.VName
				WHERE i.VName = 'isCalculatingParlay'
			)
	BEGIN
		SET @str = 'DBCC INPUTBUFFER(' + CONVERT(NVARCHAR(100),@@SPID) + ') WITH NO_INFOMSGS'
		INSERT INTO @tmp (eventtype,parameter,sqltext)
		EXEC(@str)
	
		SELECT @hostname = hostname 
		FROM sys.sysprocesses
		WHERE spid = @@SPID	

		SELECT @IP = c.local_net_address
		FROM sys.dm_exec_connections AS c
		WHERE c.session_id = @@SPID

		SELECT @VValue  = i.VValue FROM INSERTED i

		INSERT INTO Settlement_Tracking175251 (	IP,username,dtime,sqltext ,hostname ,VValue)
		SELECT  @IP,SYSTEM_USER, CURRENT_TIMESTAMP, sqltext , @hostname, @VValue
		FROM @tmp
	END

END

