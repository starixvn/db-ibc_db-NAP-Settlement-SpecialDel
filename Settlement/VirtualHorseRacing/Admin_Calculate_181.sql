ALTER PROCEDURE [Admin_Calculate_181]
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

DECLARE @modds smallmoney, @odds smallmoney, @rowcount int
DECLARE @Horse TABLE (orid int, EventID int , placing tinyint)

INSERT INTO @Horse (orid, EventID, placing)
SELECT orid, EventID, placing
FROM DBPRO.bodb02.dbo.VSoutright with (nolock)
WHERE
    EventID = @matchid

CREATE TABLE #TempData	(transid bigint, stake money NULL , odds smallmoney NULL , modds smallmoney NULL , 
		hdp1 smallmoney NULL , hdp2 smallmoney NULL , livehomescore smallint NULL, liveawayscore smallint NULL,
		apositiontaking smallmoney NULL , mpositiontaking smallmoney NULL , spositiontaking smallmoney NULL , 
		playerdiscount decimal(9,8) null, discount decimal(9,8) null, adiscount decimal(9,8) null, sdiscount decimal(9,8) null,
		WinLost money NULL, aWinLost money NULL, mWinLost money NULL, sWinLost money NULL, 
		PlayerComm money NULL, comm money NULL, acomm money NULL, scomm money NULL,
		StatusID tinyint NULL, bettype smallint NULL, placing int NULL)

-- WIN & PLACE
insert INTO #TempData 
	(transid, stake, odds, modds, hdp1, hdp2, livehomescore, liveawayscore,
		apositiontaking, mpositiontaking, spositiontaking, 
		playerdiscount,discount, adiscount, sdiscount,
		WinLost, aWinLost, mWinLost, sWinLost, 
		PlayerComm, comm, acomm, scomm,
		StatusID, bettype, placing)		
SELECT	transid, stake, odds, modds, hdp1, hdp2, livehomescore, liveawayscore,
		apositiontaking, mpositiontaking, spositiontaking, 
		playerdiscount,discount, adiscount, sdiscount,
		WinLost, aWinLost, mWinLost, sWinLost, 
		PlayerComm, comm, acomm, scomm,
		StatusID, bettype, placing
FROM bettrans with(rowlock) join @Horse h
	ON bettrans.matchid = h.EventID and bettrans.oddsid = h.orid
WHERE
    bettrans.Matchid = @matchid
    AND bettrans.bettype IN (1231, 1232)
    --[status] NOT IN (N'VOID', N'REJECT')
	AND bettrans.[statusID] NOT IN (101,102)

set @rowcount = @@ROWCOUNT

if @rowcount>0
BEGIN
	-- Win/Place
	UPDATE #TempData 
	SET		   
		@modds = modds = CASE			
			WHEN bettype = 1231 and isnull(placing,0)= 1 THEN 1 
            WHEN bettype = 1232 and isnull(placing,0)> 0 THEN 1 
			ELSE -1 -- Other Case : lose
			END,
		-- Ticket result details       
		hdp1 = CASE bettype WHEN 1232 THEN 0 ELSE Odds END, -- 'Place' bettype not have WinOdds value        
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
			WHEN @modds >  0.25	THEN stake * Odds
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
END			

-- UPDATE bettrans FROM details of Win/Place
INSERT INTO #TempData(transid, modds, hdp1, hdp2, livehomescore, liveawayscore,				
		WinLost, aWinLost, mWinLost, sWinLost, 
		PlayerComm, comm, acomm, scomm,
		StatusID, bettype  )
SELECT	transid, 
		modds = CASE 
				  WHEN bm.winlost > 0 THEN 1 				  
				  ELSE -1 END, 
		bm.hdp1, bm.hdp2, bm.livehomescore, bm.liveawayscore,				
		bm.WinLost, bm.aWinLost, bm.mWinLost, bm.sWinLost, 
		bm.PlayerComm, bm.comm, bm.acomm, bm.scomm,		
		statusID = CASE							
					WHEN bm.winlost > 0 THEN 112 --WON
					ELSE 113 -- lose
				END	
		, bettype
FROM 
dbo.bettrans with(rowlock) join 
(
	SELECT
		refno, matchid ,
		SUM(hdp1) hdp1, SUM(hdp2) hdp2,
		SUM(livehomescore) livehomescore, SUM(liveawayscore) liveawayscore,
		SUM(winlost) winlost, SUM(awinlost) awinlost, SUM(mwinlost) mwinlost, SUM(swinlost) swinlost,
		SUM(playercomm) playercomm, SUM(comm) comm, SUM(acomm) acomm, SUM(scomm) scomm
		--SUM(winlost * oddsspread) ibcwinlost
	FROM dbo.bettransm bm with (nolock)
		INNER JOIN @Horse h ON bm.matchid = h.EventID and bm.oddsid = h.orid
	where bm.matchid = @matchid	AND bm.bettype IN (1231, 1232)		
	GROUP BY bm.refno , bm.matchid
) bm on bettrans.refno = bm.refno AND bettrans.matchid = bm.matchid 
WHERE bettrans.bettype = 1233
	--[status] NOT IN (N'VOID', N'REJECT')
	AND bettrans.[statusID] NOT IN (101,102)

set @rowcount = @rowcount + @@ROWCOUNT
IF @rowcount  = 0 RETURN			

DECLARE @_xml XML, @_sXML varchar(MAX)
DECLARE @subtable TABLE(transid bigint, winlost money, awinlost money, mwinlost money, swinlost money,
	playercomm money, comm money, acomm money, scomm money, statusid tinyint, 
	modds smallmoney, hdp1 smallmoney, hdp2 smallmoney,livehomescore smallint, liveawayscore smallint)
	
WHILE (1 = 1)
BEGIN
	DELETE @subtable

	DELETE TOP (20) #TempData
	OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost, 	
		deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm, deleted.statusid, 
		deleted.modds, deleted.hdp1, deleted.hdp2, deleted.livehomescore, deleted.liveawayscore
	INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, 
		modds, hdp1, hdp2, livehomescore, liveawayscore)	
	
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
			,NULLIF(modds,0) '@f'
			,NULLIF(hdp1,0) '@h1'
			,NULLIF(hdp2,0) '@h2'
			,NULLIF(livehomescore,0) '@l1'
			,NULLIF(liveawayscore,0) '@l2'
		FROM @subtable
		FOR XML PATH('r'), ROOT('root'), TYPE
	) 
	SELECT @_sXML = CONVERT(varchar(max), @_xml)
	
	EXEC dbo.Bet_ExecRep_05 @IgnoreList, 3, @_sXML

	--- LAS settlement 
	SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_VS_s181] @_sXML = ''' + @_sXML + ''''
			,@createdDate = GETDATE()
		
	BEGIN TRY
		EXEC DBLAS.LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_VS_s181'
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
							@ActionID = 40023, 
							@Remark = @Remark
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
							@UserID = NULL, 
							@Matchid = @matchid, 
							@ActionID = 40023, 
							@Remark = @Remark
		END CATCH
	END CATCH
		 					
END

GO
GRANT EXECUTE ON [dbo].[Admin_Calculate_181] TO [Dot_Member] AS [dbo]