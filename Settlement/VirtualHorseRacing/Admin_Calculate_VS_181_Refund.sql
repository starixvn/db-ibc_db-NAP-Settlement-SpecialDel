/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Admin_Calculate_VS_181_Refund]
	@matchid int	
AS
/*
	Created by: Victor
	Date:[20130114]
	Task: Settlement (Refund)
	DB: DBTRANS.bodb02
	
	Revisions:		
		- 20140514@Kathy: insert settled command into LAS queue [Redmine:#14286]
		- 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]

*/
SET NOCOUNT ON
BEGIN
	IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044', 'DB054', 'DB055')
	BEGIN
		--Refund for bettransm
		UPDATE dbo.bettransm with (ROWLOCK, UPDLOCK)
		SET
			[status] = 'Refund',
			statusID = 103,
			winlost=stake,
			livehomescore=0, liveawayscore=0,
			awinlost=0, mwinlost=0, swinlost=0,
			playercomm=0, comm=0, acomm=0, scomm=0,
			ruben=1
		WHERE 
			bettransm.matchid = @matchid
			AND bettransm.bettype IN (1231,1232)
			AND bettransm.[statusID] NOT IN (101,102)
	END


	IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044', 'DB054', 'DB055')
	BEGIN
		-- Refund ticket
		UPDATE dbo.bettrans with (ROWLOCK, UPDLOCK)
		SET
			[status] = 'Refund',
			statusID = 103,
			winlost=actual_stake,
			livehomescore=0, liveawayscore=0,
			awinlost=0, mwinlost=0, swinlost=0,
			playercomm=0, comm=0, acomm=0, scomm=0,
			ruben=1
		WHERE 
			bettrans.matchid = @matchid
			AND bettrans.bettype IN (1231,1232,1233)
			AND bettrans.[statusID] NOT IN (101,102)
	END


	IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044', 'DB054', 'DB055')
	BEGIN
		Declare @LASCommand NVARCHAR(max),@createdDate DATETIME

		--- LAS settlement 
		SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_VS_s181_Refund] @matchid = ' + convert(varchar(20),@matchid)
				,@createdDate = GETDATE()
		
		BEGIN TRY
			EXEC DBLAS.LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_VS_s181_Refund'
				,@SQLCommand = @LASCommand
				,@CreatedDate = @createdDate
				,@StatusID = 0 -- waiting
				,@MatchID = @matchid
				,@Bettype = NULL
				,@Status = 'waiting'
				,@BetCount = NULL
		END TRY
		BEGIN CATCH			
			BEGIN TRY			
				EXEC DBLOG.bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
								@UserID = NULL, 
								@Matchid = @matchid, 
								@ActionID = 40024, 
								@Remark = @LASCommand
			END TRY
			BEGIN CATCH
				EXEC bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
								@UserID = NULL, 
								@Matchid = @matchid, 
								@ActionID = 40024, 
								@Remark = @LASCommand
			END CATCH
		END CATCH
	END
END
GO