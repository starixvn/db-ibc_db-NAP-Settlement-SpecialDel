USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Admin_3rdCalculate_s151_Admin]    Script Date: 08/07/2015 14:41:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Admin    Script Date: 3/1/2013 4:00:54 AM ******/
/****** Object:  Stored Procedure dbo.Admin_3rdCalculate_s151_Admin    Script Date: 2/22/2013 5:35:48 PM ******/
ALTER PROCEDURE [dbo].[Admin_3rdCalculate_s151_Admin]
    @LeagueID int, --settle leagueid
    @raceNumber tinyint, -- settle race no
    @EventDate smalldatetime
AS
    -- 20100517@Henry: Update column StatusID of Bettrans, Bettransm
    -- 20100521@Henry: Change to use StatusID instead of Status in WHERE statement
    -- 20120430@AllenWu: Apply new credit balance procedure
    -- 20120713@victor:	remove IF EXISTS(SELECT orid FROM @Horse)
	-- 20120717@Cooper: add try catch 
    -- 20130121@Elodie: Change link server DB02 to DBPRO
    -- 20150807@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
	-- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
    
    DECLARE @Horse TABLE (orid int, placing tinyint, WinOdds money, PlaceOdds money, IsSCR bit)
    DECLARE @DeadHeat TABLE (placing tinyint)
    DECLARE @IsPlaceRefund bit

BEGIN TRY

    INSERT INTO @Horse (orid, placing, WinOdds, PlaceOdds, IsSCR)
    SELECT orid, placing, IsNull(Odds, 0), IsNull(PlaceOdds, 0), IsSCR
    FROM DBPRO.BODB02.dbo.outright with (nolock)
    WHERE
        LeagueID = @LeagueID
        AND groupmatch = CAST(@raceNumber as varchar(20))
        AND eventdate = @EventDate
        AND oddsstatus = 'closed'

-------------------------------------------------------------
---        CAPTURE value BALANCE before settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)
 
        INSERT INTO #BalanceBefore
        SELECT  custid,sum( winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse)
        AND bettrans.bettype IN (31, 32, 33) 
        and statusID NOT IN (101)
		group by custid

    -- Check for DeadHeat result
    INSERT INTO @DeadHeat
    SELECT placing
    FROM @Horse
    WHERE placing > 0
    GROUP BY placing
    HAVING COUNT(*) > 1

    -- 20090215 : fixed the PlaceOdds which below 1.0 (Joe)
    -- 20090314 : add condition to exclude deadheat for odds below 1.0 exception
    UPDATE @Horse SET PlaceOdds = 1.0 WHERE PlaceOdds <> 0 AND PlaceOdds < 1.0 AND placing NOT IN (select placing FROM @DeadHeat)
    UPDATE @Horse SET WinOdds   = 1.0 WHERE WinOdds   <> 0 AND WinOdds   < 1.0 AND placing NOT IN (select placing FROM @DeadHeat)

    -- 20090219 : if Place become refund, due to not enough runner or whatever reason
    -- right now, we consider by no PlaceOdds (all zero)
    IF EXISTS(SELECT * FROM @Horse WHERE PlaceOdds > 0)
        SET @IsPlaceRefund = 0
    ELSE
        BEGIN
            SET @IsPlaceRefund = 1
            UPDATE @Horse SET PlaceOdds = 1.0
        END


    DECLARE @modds money, @odds money,
            @EffectStake money, @EffectOdds money
    -- ===============================

	-- WIN & PLACE
    UPDATE dbo.bettrans with (UPDLOCK, ROWLOCK)
    SET
        @odds = CASE bettype
            WHEN 31 THEN h.WinOdds
            WHEN 32 THEN h.PlaceOdds
            WHEN 33 THEN (h.WinOdds + h.PlaceOdds) / 2
                /* case
                when h.placing = 1      then (h.WinOdds + h.PlaceOdds) / 2 -- win both Win & Place
                when h.placing IN (2,3) then h.PlaceOdds/2 -- win only Place
                else 0 -- full lose
                end */
            END,
		odds = @odds,
        @modds = CASE
            WHEN h.IsSCR =  1 THEN 0 -- draw (cancel)
            WHEN bettype = 31 AND @odds > 0 /*h.placing = 1*/ THEN 1 -- Win : Horse come 1st place
            WHEN bettype = 32 AND @odds > 0 /*h.placing IN (1,2,3)*/ THEN 1 -- Place : Horse come within 3rd place
            WHEN bettype = 33 AND @odds > 0 /*h.placing IN (1,2,3)*/ THEN 1 -- Each Way : Horse come within 3rd place
            ELSE -1 -- Other Case : lose
            END,
		modds = @modds,
        -- Value uses for calculate Agent Winlost & Commission
        @EffectStake = CASE
            WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN 0
            WHEN bettype = 33 AND @IsPlaceRefund = 1 THEN actual_stake / 2
            ELSE actual_stake
            END,
        @EffectOdds = CASE
            WHEN @IsPlaceRefund = 1 AND bettype = 33 THEN h.WinOdds
            ELSE @odds
            END,

        -- Ticket result details
        hdp1 = CASE bettype WHEN 32 THEN 0 ELSE h.WinOdds   END, -- 'Place' bettype not have WinOdds value
        hdp2 = CASE bettype WHEN 31 THEN 0 ELSE h.PlaceOdds END, -- 'Win'   bettype not have PlaceOdds value
        livehomescore = CASE -- Win result : 2 = Win / 4 = Lose
            WHEN bettype IN (31, 33) AND h.placing =  1 THEN 2
            WHEN bettype IN (31, 33) AND h.placing <> 1 THEN 4
            ELSE 0 END,
        liveawayscore = CASE -- Place result : 0 = Refund
            WHEN @IsPlaceRefund = 1 THEN 0
            WHEN bettype IN (32, 33) AND h.PlaceOdds > 0 THEN 2
            WHEN bettype IN (32, 33) AND h.PlaceOdds = 0 THEN 4
            ELSE 0 END,

    [status] = CASE
        WHEN @modds = 0 THEN N'VOID' -- only case to be draw :: IsSCR = 1
		WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN N'Refund'        
        --WHEN @odds  < 1 THEN N'LOSE'
        WHEN @modds > 0 THEN N'WON'
        WHEN @modds < 0 THEN N'LOSE'
        END,
     statusID = CASE
		WHEN @modds = 0 THEN 102
		WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN 103
        WHEN @modds > 0 THEN 112
        WHEN @modds < 0 THEN 113
        END,

    WinLost = CASE
        WHEN @modds >  0.25		THEN actual_stake * @odds
        WHEN @modds =  0		THEN actual_stake
        WHEN @modds < -0.25		THEN 0
        --WHEN @modds =  0.25    THEN actual_stake + stake * (@odds - 1) * 0.5
        --WHEN @modds = -0.25    THEN actual_stake * 0.5
        END,

    aWinLost = CASE
        WHEN @modds >  0.25		THEN @EffectStake * (@EffectOdds - 1) * -apositiontaking
        WHEN @modds =  0		THEN 0
        WHEN @modds < -0.25		THEN @EffectStake * apositiontaking
        --WHEN @modds =  0.25    THEN stake * (@odds - 1) * -apositiontaking * 0.5
        --WHEN @modds = -0.25    THEN actual_stake * apositiontaking * 0.5
        END,
    mWinLost = CASE
        WHEN @modds >  0.25     THEN @EffectStake * (@EffectOdds - 1) * -mpositiontaking
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN @EffectStake * mpositiontaking
        --WHEN @modds =  0.25     THEN stake * (@odds - 1) * -mpositiontaking * 0.5
        --WHEN @modds = -0.25     THEN actual_stake * mpositiontaking * 0.5
        END,
    sWinLost = CASE
        WHEN @modds >  0.25     THEN @EffectStake * (@EffectOdds - 1) * -spositiontaking
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN @EffectStake * spositiontaking
        --WHEN @modds =  0.25     THEN stake * (@odds - 1) * -spositiontaking * 0.5
        --WHEN @modds = -0.25     THEN actual_stake * spositiontaking * 0.5
        END,

    PlayerComm = CASE
        WHEN @modds >  0.25     THEN playerdiscount * @EffectStake
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN playerdiscount * @EffectStake
        --WHEN @modds =  0.25     THEN playerdiscount * stake * 0.5
        --WHEN @modds = -0.25     THEN playerdiscount * stake * 0.5
        END,
    Comm = CASE
        WHEN @modds >  0.25     THEN discount * @EffectStake * (1-apositiontaking)
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN discount * @EffectStake * (1-apositiontaking)
        --WHEN @modds =  0.25     THEN discount * stake * (1-apositiontaking) * 0.5
        --WHEN @modds = -0.25     THEN discount * stake * (1-apositiontaking) * 0.5
        END,
    aComm = CASE
        WHEN @modds >  0.25     THEN adiscount * @EffectStake * (1-(mpositiontaking+apositiontaking))
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN adiscount * @EffectStake * (1-(mpositiontaking+apositiontaking))
        --WHEN @modds =  0.25     THEN adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
        --WHEN @modds = -0.25     THEN adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
        END,
    sComm = CASE
        WHEN @modds >  0.25     THEN sdiscount * @EffectStake * (1-(spositiontaking+mpositiontaking+apositiontaking))
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN sdiscount * @EffectStake * (1-(spositiontaking+mpositiontaking+apositiontaking))
        --WHEN @modds =  0.25     THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
        --WHEN @modds = -0.25     THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
        END,

    ruben=1

    FROM @Horse h
    WHERE
        bettrans.matchid = h.orid
        AND bettrans.bettype IN (31, 32)
        --AND bettrans.[status] NOT IN (N'REJECT')
        AND bettrans.[statusID] NOT IN (101)


	-- Details of Win/Place

    UPDATE dbo.bettransm with (UPDLOCK, ROWLOCK)
    SET
        @odds = CASE bettype
            WHEN 31 THEN h.WinOdds
            WHEN 32 THEN h.PlaceOdds
            END,
		odds = @odds,
        @modds = CASE
            WHEN h.IsSCR =  1 THEN 0 -- draw (cancel)
            WHEN bettype = 31 AND @odds > 0 THEN 1 -- Win : Horse come 1st place
            WHEN bettype = 32 AND @odds > 0 THEN 1 -- Place : Horse come within 3rd place
            ELSE -1 -- Other Case : lose
            END,

        -- Value uses for calculate Agent Winlost & Commission
        @EffectStake = CASE
            WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN 0
            ELSE stake
            END,
        @EffectOdds = @odds,

        -- Ticket result details
        hdp1 = CASE bettype WHEN 32 THEN 0 ELSE h.WinOdds   END, -- 'Place' bettype not have WinOdds value
        hdp2 = CASE bettype WHEN 31 THEN 0 ELSE h.PlaceOdds END, -- 'Win'   bettype not have PlaceOdds value
        livehomescore = CASE -- Win result : 2 = Win / 4 = Lose
            WHEN bettype IN (31, 33) AND h.placing =  1 THEN 2
            WHEN bettype IN (31, 33) AND h.placing <> 1 THEN 4
            ELSE 0 END,
        liveawayscore = CASE -- Place result : 0 = Refund
            WHEN @IsPlaceRefund = 1 THEN 0
            WHEN bettype IN (32, 33) AND h.PlaceOdds > 0 THEN 2
            WHEN bettype IN (32, 33) AND h.PlaceOdds = 0 THEN 4
            ELSE 0 END,

    [status] = CASE
        WHEN @modds = 0 THEN N'VOID' -- only case to be draw :: IsSCR = 1
		WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN N'Refund'        
        --WHEN @odds  < 1 THEN N'LOSE'
        WHEN @modds > 0 THEN N'WON'
        WHEN @modds < 0 THEN N'LOSE'
        END,
    statusID = CASE
        WHEN @modds = 0 THEN 102
        WHEN bettype = 32 AND @IsPlaceRefund = 1 THEN 103
        WHEN @modds > 0 THEN 112
        WHEN @modds < 0 THEN 113
        END,

    WinLost = CASE
        WHEN @modds >  0.25	THEN stake * @odds
        WHEN @modds =  0	THEN stake
        WHEN @modds < -0.25	THEN 0
        END,

    aWinLost = CASE
        WHEN @modds >  0.25	THEN @EffectStake * (@EffectOdds - 1) * -apositiontaking
        WHEN @modds =  0	THEN 0
        WHEN @modds < -0.25	THEN @EffectStake * apositiontaking
        END,
    mWinLost = CASE
        WHEN @modds >  0.25	THEN @EffectStake * (@EffectOdds - 1) * -mpositiontaking
        WHEN @modds =  0	THEN 0
        WHEN @modds < -0.25	THEN @EffectStake * mpositiontaking
        END,
    sWinLost = CASE
        WHEN @modds >  0.25	THEN @EffectStake * (@EffectOdds - 1) * -spositiontaking
        WHEN @modds =  0	THEN 0
        WHEN @modds < -0.25	THEN @EffectStake * spositiontaking
        END,

    PlayerComm = CASE
        WHEN @modds >  0.25     THEN playerdiscount * @EffectStake
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN playerdiscount * @EffectStake
        END,
    Comm = CASE
        WHEN @modds >  0.25     THEN discount * @EffectStake * (1-apositiontaking)
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN discount * @EffectStake * (1-apositiontaking)
        END,
    aComm = CASE
        WHEN @modds >  0.25     THEN adiscount * @EffectStake * (1-(mpositiontaking+apositiontaking))
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN adiscount * @EffectStake * (1-(mpositiontaking+apositiontaking))
        END,
    sComm = CASE
        WHEN @modds >  0.25     THEN sdiscount * @EffectStake * (1-(spositiontaking+mpositiontaking+apositiontaking))
        WHEN @modds =  0        THEN 0
        WHEN @modds < -0.25     THEN sdiscount * @EffectStake * (1-(spositiontaking+mpositiontaking+apositiontaking))
        END,

    ruben=1

    FROM @Horse h
    WHERE
        bettransm.matchid = h.orid
        AND bettransm.bettype IN (31, 32)
        --AND bettransm.[status] NOT IN (N'REJECT')
		AND bettransm.[statusID] NOT IN (101)


	-- UPDATE bettrans FROM details of Win/Place
    UPDATE dbo.bettrans with (UPDLOCK, ROWLOCK)
	SET
		livehomescore = bm.livehomescore, liveawayscore = bm.liveawayscore,
		winlost = bm.winlost, awinlost = bm.awinlost, mwinlost = bm.mwinlost, swinlost = bm.swinlost,
		playercomm = bm.playercomm, comm = bm.comm, acomm = bm.acomm, scomm = bm.scomm,
		apositiontaking = CASE WHEN bm.liveawayscore = 0 THEN bm.apositiontaking ELSE bettrans.apositiontaking END,
		mpositiontaking = CASE WHEN bm.liveawayscore = 0 THEN bm.mpositiontaking ELSE bettrans.mpositiontaking END,
		spositiontaking = CASE WHEN bm.liveawayscore = 0 THEN bm.spositiontaking ELSE bettrans.spositiontaking END,
		tpositiontaking = CASE WHEN bm.liveawayscore = 0 THEN bm.tpositiontaking ELSE bettrans.tpositiontaking END,
		--oddsspread = ibcwinlost/bm.winlost,
		hdp1 = bm.hdp1, hdp2 = bm.hdp2,
		odds = CASE WHEN bm.liveawayscore = 0 THEN bm.hdp1 ELSE (bm.hdp1 + bm.hdp2)/2 END , 
		oddsspread = CASE WHEN bm.liveawayscore = 0 THEN bm.oddsspread ELSE bettrans.oddsspread END, 

		@modds = CASE WHEN bm.IsSCR = 1 THEN 0 
							  WHEN (CASE WHEN bm.liveawayscore = 0 THEN bm.winlost - bettrans.actual_stake/2 ELSE bm.winlost END) > 0 THEN 1 
							  ELSE -1 END,
		modds = @modds,
		[status] = CASE
			WHEN @modds = 0 THEN N'VOID' -- only case to be draw :: IsSCR = 1
			--WHEN @odds  < 1 THEN N'LOSE'
			WHEN @modds > 0 THEN N'WON'
	        WHEN @modds < 0 THEN N'LOSE'
			END,
		statusID = CASE
			WHEN @modds = 0 THEN 102
			WHEN @modds > 0 THEN 112
	        WHEN @modds < 0 THEN 113
			END,
		ruben = 1
	FROM (
		SELECT
			refno, h.orid, h.IsSCR,
			SUM(case when bettype = 31 then apositiontaking else 0 end)apositiontaking, 
			SUM(case when bettype = 31 then mpositiontaking else 0 end)mpositiontaking, 
			SUM(case when bettype = 31 then spositiontaking else 0 end)spositiontaking,
			SUM(case when bettype = 31 then tpositiontaking else 0 end)tpositiontaking,
			SUM(case when bettype = 31 then isnull(oddsspread,0) else 0 end) oddsspread,
			SUM(hdp1) hdp1, SUM(hdp2) hdp2,
			SUM(livehomescore) livehomescore, SUM(liveawayscore) liveawayscore,
			SUM(winlost) winlost, SUM(awinlost) awinlost, SUM(mwinlost) mwinlost, SUM(swinlost) swinlost,
			SUM(playercomm) playercomm, SUM(comm) comm, SUM(acomm) acomm, SUM(scomm) scomm,
			SUM(winlost * oddsspread) ibcwinlost
		FROM dbo.bettransm bm with (nolock)
		INNER JOIN @Horse h ON bm.matchid = h.orid
		GROUP BY bm.refno, h.orid, h.IsSCR
	) bm
	WHERE
		bettrans.transid = bm.refno
		AND bettrans.matchid = bm.orid
		AND bettrans.bettype = 33
		--AND bettrans.[status] NOT IN (N'REJECT')
		AND bettrans.[statusID] NOT IN (101)

	-- LOG settle ticket

		Declare @LogData as nvarchar(300)
		SET @LogData = 'Calculate Result (+CAL) [Admin_3rdCalculate_s151_Admin] for Horse League ID:'  + CAST(@LeagueID as nvarchar(20)) + ' race:' + CAST(@raceNumber as nvarchar(20)) + ' eventdate:' + CAST(@eventdate as nvarchar(20))
		EXEC dbo.WriteLog_UserLog 151, @LogData

	
-------------------------------------------------------------
---         CAPTURE value BALANCE after settlement        ---
---------------------------VVVV------------------------------
CREATE TABLE #BalanceAfter (custid int PRIMARY KEY , balance money)
 
        INSERT INTO #BalanceAfter
        SELECT  custid,sum( winlost-actual_stake+playercomm)
        FROM dbo.bettrans with (rowlock)
        WHERE matchid in (select orid from @Horse)
        AND bettrans.bettype IN (31, 32, 33)  
        and statusID NOT IN (101)
		Group by custid
       
-------------------------------------------------------------
---                   compare BALANCE                     ---
---------------------------VVVV------------------------------
CREATE TABLE #Balance (custid int not null, balance money, Increased bit not null)
ALTER TABLE #Balance add constraint pk_C2 primary key (custid, Increased);

DECLARE @tblDebitPending TVP_BalanceList
DECLARE @tblCreditPending TVP_BalanceList
	
CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
 

INSERT INTO #Balance
SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
FROM #BalanceBefore b
        INNER JOIN #BalanceAfter a ON b.custid = a.custid
WHERE b.balance <> a.balance

--INSERT INTO dbo.BalancePendingDebit (custid, balance)
--SELECT custid, ABS(balance)
--FROM #Balance
--WHERE Increased = 0

INSERT INTO @tblDebitPending (custID, balance)
SELECT	custid, ABS(balance)
FROM	#Balance
WHERE	Increased = 0

IF @@rowcount <> 0
	EXEC dbo.Dot_BalancePendingDebitIns 
		@BalancePending = @tblDebitPending
		,@Type			= 4 -- Others
 
--INSERT INTO dbo.BalancePendingCredit (custid, balance)
--SELECT custid, balance
--FROM #Balance
--WHERE Increased = 1   

INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance
	WHERE	Increased = 1
	
IF @@rowcount <> 0
	EXEC dbo.Dot_BalancePendingCreditIns 
		@BalancePending = @tblCreditPending
		,@Type			= 4 -- Others
 
DROP TABLE #Balance
DROP TABLE #BalanceBefore
DROP TABLE #BalanceAfter

END TRY
BEGIN CATCH
			SET @LogData = 'Admin_3rdCalculate_s151_Admin_ErrorNumber:' + cast ( ERROR_NUMBER() as varchar(10) )
			+'.ErrorSeverity:' + cast ( ERROR_SEVERITY() as varchar(10))
			+'.ErrorState:' + cast ( ERROR_STATE() as varchar(10) )
			+'.ErrorProcedure:' + isnull(ERROR_PROCEDURE(),'')
			+'.ErrorLine:' + cast ( ERROR_LINE() as varchar(10) )
			+'.ErrorMessage:' +ERROR_MESSAGE() 
			EXEC dbo.WriteLog_UserLog 151, @LogData
END CATCH

GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Admin] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Admin] TO [Dot_3rdparty] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Admin_3rdCalculate_s151_Admin] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Admin_3rdCalculate_s151_Admin] TO [vnteam] AS [dbo]