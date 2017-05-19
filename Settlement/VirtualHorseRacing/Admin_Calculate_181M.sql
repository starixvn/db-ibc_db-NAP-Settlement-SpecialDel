ALTER PROCEDURE [Admin_Calculate_181M]
	@matchid int
AS
/*
	Created by:[Victor]
	Date:[20130115]
	Task: Settlement 
	DB: DBTrans.BODB02

	Revisions:
		- 20140512@Kathy: insert settled command into LAS queue [Redmine:#14286]
	
*/
SET NOCOUNT ON
DECLARE @IgnoreList varchar(200)
	,@LASCommand NVARCHAR(max),@createdDate DATETIME, @Remark varchar(500)

SET @IgnoreList = 'DB04,DB042,DB043,DB044'	

SELECT @LASCommand = '',
		@Remark = ''

DECLARE @modds smallmoney

DECLARE @Horse TABLE (orid int, EventID int , placing tinyint)

INSERT INTO @Horse (orid, EventID, placing)
SELECT orid, EventID, placing
FROM DBPRO.bodb02.dbo.VSoutright with (nolock)
WHERE
    EventID = @matchid

SELECT	transid, stake, odds, hdp1, hdp2, livehomescore, liveawayscore,
		apositiontaking, mpositiontaking, spositiontaking, 
		playerdiscount,discount, adiscount, sdiscount,
		WinLost, aWinLost, mWinLost, sWinLost, 
		PlayerComm, comm, acomm, scomm,
		StatusID, bettype, placing		
INTO #TempData		
FROM bettransm with(rowlock) join @Horse h
	ON bettransm.matchid = h.EventID and bettransm.oddsid = h.orid
WHERE
    bettransm.Matchid = @matchid
    AND bettransm.bettype IN (1231, 1232)
    --[status] NOT IN (N'VOID', N'REJECT')
	AND bettransm.[statusID] NOT IN (101,102)

IF @@ROWCOUNT = 0 RETURN		

-- Details of Win/Place
UPDATE #TempData
SET	
    @modds = CASE        
        WHEN bettype = 1231 and isnull(placing,0)= 1 THEN 1 
        WHEN bettype = 1232 and isnull(placing,0)> 0 THEN 1 
        ELSE -1 -- Other Case : lose
        END,
    -- Ticket result details        
    hdp1 = CASE bettype WHEN 1232 THEN 0 ELSE Odds   END, -- 'Place' bettype not have WinOdds value        
    hdp2 = CASE bettype WHEN 1231 THEN 0 ELSE Odds END, -- 'Win'   bettype not have PlaceOdds value
    livehomescore = CASE -- Win result : 2 = Win / 4 = Lose        
        WHEN bettype = 1231 AND isnull(placing,0)= 1 THEN 2
        WHEN bettype = 1231 AND isnull(placing,0)<> 1 THEN 4
        ELSE 0 END,
    liveawayscore = CASE -- Place result : 0 = Refund
        WHEN bettype = 1232 AND isnull(placing,0)> 0 THEN 2
        WHEN bettype = 1232 AND isnull(placing,0)=0 THEN 4
        ELSE 0 END,    
	statusID = CASE
		WHEN @modds > 0 THEN 112
		WHEN @modds < 0 THEN 113
		END,
	WinLost = CASE
		WHEN @modds >  0.25	THEN stake * odds
		WHEN @modds < -0.25	THEN 0
		END,

	aWinLost = CASE
		WHEN @modds >  0.25	THEN Stake * (Odds - 1) * -apositiontaking
		WHEN @modds < -0.25	THEN Stake * apositiontaking
		END,
	mWinLost = CASE
		WHEN @modds >  0.25	THEN Stake * (Odds - 1) * -mpositiontaking
		WHEN @modds < -0.25	THEN Stake * mpositiontaking
		END,
	sWinLost = CASE
		WHEN @modds >  0.25	THEN Stake * (Odds - 1) * -spositiontaking
		WHEN @modds < -0.25	THEN Stake * spositiontaking
		END,

	PlayerComm = CASE
		WHEN @modds >  0.25     THEN playerdiscount * Stake
		WHEN @modds < -0.25     THEN playerdiscount * Stake
		END,
	Comm = CASE
		WHEN @modds >  0.25     THEN discount * Stake * (1-apositiontaking)
		WHEN @modds < -0.25     THEN discount * Stake * (1-apositiontaking)
		END,
	aComm = CASE
		WHEN @modds >  0.25     THEN adiscount * Stake * (1-(mpositiontaking+apositiontaking))
		WHEN @modds < -0.25     THEN adiscount * Stake * (1-(mpositiontaking+apositiontaking))
		END,
	sComm = CASE
		WHEN @modds >  0.25     THEN sdiscount * Stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
		WHEN @modds < -0.25     THEN sdiscount * Stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
		END


DECLARE @_xml XML, @_sXML varchar(MAX)
DECLARE @subtable TABLE(transid bigint, winlost money, awinlost money, mwinlost money, swinlost money,
	playercomm money, comm money, acomm money, scomm money, statusid tinyint, 
	hdp1 smallmoney, hdp2 smallmoney,livehomescore smallint, liveawayscore smallint)
	
WHILE (1 = 1)
BEGIN
	DELETE @subtable
	
	DELETE TOP (20) #TempData
	OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost, 	
		deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm, deleted.statusid, 
		deleted.hdp1, deleted.hdp2, deleted.livehomescore, deleted.liveawayscore
	INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, 
			statusid, hdp1, hdp2, livehomescore, liveawayscore)	
	
	IF @@ROWCOUNT = 0 BREAK
	
	SET @_xml = (
		SELECT 
			transid '@q'
			,NULLIF(winlost,0) '@a'
			,NULLIF(awinlost,0) '@z'
			,NULLIF(mwinlost,0) '@w'				
			,NULLIF(swinlost,0) '@s'
			,NULLIF(playercomm,0) '@x'
			,NULLIF(comm,0) '@e'
			,NULLIF(acomm,0) '@d'
			,NULLIF(scomm,0) '@c'	
			,statusid '@r'							
			,NULLIF(hdp1,0) '@h1'
			,NULLIF(hdp2,0) '@h2'
			,NULLIF(livehomescore,0) '@l1'
			,NULLIF(liveawayscore,0) '@l2'
		FROM @subtable
		FOR XML PATH('r'), ROOT('root'), TYPE
	) 
	SELECT @_sXML = CONVERT(varchar(max), @_xml)
	
	EXEC dbo.Bet_ExecRep_05 @IgnoreList, 2, @_sXML

	--- LAS settlement 
	SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_VS_s181M] @_sXML = ''' + @_sXML + ''''
			,@createdDate = GETDATE()
		
	BEGIN TRY
		EXEC DBLAS.LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_VS_s181M'
			,@SQLCommand = @LASCommand
			,@CreatedDate = @createdDate
			,@StatusID = 0 -- waiting
			,@MatchID = @matchid
			,@Bettype = NULL
			,@Status = 'waiting'
			,@BetCount = NULL
	END TRY
	BEGIN CATCH			
		SELECT @Remark = @Remark + CAST(transid as varchar(20)) + ','
		FROM @subtable

		SET @Remark = SUBSTRING(@Remark, 1, LEN(@Remark)-1)

		BEGIN TRY			
			EXEC DBLOG.bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
							@UserID = NULL, 
							@Matchid = @matchid, 
							@ActionID = 40022, 
							@Remark = @Remark
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
							@UserID = NULL, 
							@Matchid = @matchid, 
							@ActionID = 40022, 
							@Remark = @Remark
		END CATCH
	END CATCH
			 				
		 					
END
		

GO
GRANT EXECUTE ON [dbo].[Admin_Calculate_181M] TO [Dot_Member] AS [dbo]