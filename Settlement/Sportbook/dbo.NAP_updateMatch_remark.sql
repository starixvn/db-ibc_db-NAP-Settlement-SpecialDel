/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_updateMatch_remark]
	@matchid 			INT,
	@command 			VARCHAR(5),
	@ivalue 			BIGINT = NULL,
	@IsHTRound 			BIT = 0,
	@IsFinalRound       BIT = 0,
	@IsMovedMatch		BIT = 1,
	@IsRefundHT			BIT = NULL,
	@IsResultHTCal		BIT = NULL
WITH RECOMPILE
/*  
	Created: Kathy
	Date: 20140213
	Task:  	--part of replication (call by settle_new_test2)
			--MUST modify in all replication if modify the code
	DB: DB02.bodb02
	Original SP: UpdateMAtch_Remark
	
	Revisions:
		- 20140711@Kathy: Add more @command value: PS for settlement Penalty Shootout [Redmine:#17142]
		- 20140905@Kathy: Update SettlementStatus135 = 4 if the match hasn't any PS ticket [Redmine:#21560]
		- 20141022@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20150418@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]	
		- 20170525@Kathy: Set calrefund = 1 when refund FT basketball  [Redmine:#77046]
		- 20170901@Kathy: Update parlay info base on user action [Redmine:#82122]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20210219@Louisa: Update match_remark when calculate HT for Basketball [Redmine:#150328]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20211108@Louisa: In-house Replicator: Update Action [Redmine:#164393] 
		- 20220719@Louisa: Update match_remark before calcualte/refund for VSBetradar [Redmine:#175251]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]

	Param's Explanation: 
*/
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @IsHTCal	BIT
			,@Calculate BIT
			,@IsPending BIT
			,@ParentMatchId	INT
			,@Sporttype SMALLINT

	SELECT	@IsHTCal		= IsHTCal
			,@Calculate 	= Calculate
			,@IsPending 	= IsPending
	FROM	match_remark WITH (NOLOCK)
	WHERE	matchid = @matchid 

	SELECT	@ParentMatchId = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULl AND m.sporttype = 50 THEN m.ParentID ELSE NULL END
			,@Sporttype = m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchID

	IF @IsMovedMatch = 0 AND @ParentMatchId IS NOT NULL -- child match of cricket
		RETURN

	IF NOT EXISTS (SELECT TOP 1 1 FROM match_remark WITH(NOLOCK) WHERE matchid = @matchid)
	BEGIN
		INSERT INTO match_remark (matchid, LiveTimer, LivePeriod, HomeRedCard, AwayRedCard, RepUpdateTime, IsDeleted) 
		VALUES (@matchid, '01 JAN 2000',0,0,0, SYSDATETIME(), 0)
	END

	--IF @command = 'Q' UPDATE match_remark with (rowlock, updlock) SET Calculate = 0, multiple = 0, calrefund = 0, calStatus = 'Q' WHERE matchid = @matchid
	
	-- Completed
	IF @command = 'C' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET Calculate		= 1
			,calrefund		= 0
			,IsHTCal		= CASE WHEN (@Sporttype = 2 AND @IsHTRound = 1) OR @Sporttype <> 2 THEN 1 ELSE IsHTCal END
			,isPending		= 0
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid -- whole match calculated
	END

	-- Half Time Calculated
	IF @command = 'H'
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET	IsHTCal			= 1 
			,isPending		= CASE WHEN @IsHTCal = 0 AND @Calculate = 0 AND @IsPending = 1 THEN 0 
								   ELSE isPending 
							  END
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END
	
	-- Match Refund
	IF @command = 'F' AND (@Sporttype <> 2
							OR (@Sporttype = 2 AND @IsFinalRound = 1)
						)
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET calculate		= 0
			,IsHTCal		= CASE WHEN @Sporttype <> 2 OR (@Sporttype = 2 AND @IsHTRound = 1) THEN 0 ELSE IsHTCal END
			,calrefund		= 1
			,isPending		= 0
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME()			
		WHERE matchid = @matchid 
	END

	IF @command = 'F' AND @Sporttype = 2 AND @IsHTRound = 1 AND @IsFinalRound = 0
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsHTCal		= 0
			,isPending		= 0
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME()			
		WHERE matchid = @matchid 
	END
	
	-- Mix Parlay calculated
	IF @command = 'M'
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET multiple		= 1
			,refund			= 0
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid 
	END
	
	-- Mix Parlay Refund
	IF @command = 'R'
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET multiple		= 0
			,refund			= 1
			,isUndecided	= 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid 
	END
	
	-- [U]ndo settlement
	IF @command = 'U' AND (@Sporttype <> 2
							OR (@Sporttype = 2 AND @IsFinalRound = 1)
							)
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET IsHTCal					= CASE WHEN (@Sporttype = 2 AND @IsFinalRound = 1) THEN IsHTCal ELSE 0 END
			,Calculate				= 0
			,multiple				= 0
			,calrefund				= 0
			,refund					= 0
			,isUndecided			= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid 
	END
	
	-- [U]ndo FT settlement
	IF @command = 'UF'
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET Calculate				= 0
			,IsHTCal				= IIF(@IsResultHTCal = 1,1,0)
			,isUndecided			= 0
			,calrefund				= IIF(@IsRefundHT = 1,1,0)
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid 
	END

	-- [U]ndo settlement of HT, Q1, Q2 Basketball
	IF @command = 'U' AND @Sporttype = 2 AND @IsHTRound = 1
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET IsHTCal					= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid 
	END
	
	-- Total Bet control session
	-- relative to UserControl of Totalbet access
	-- HedgeForecast, to tell this game have extra forecast
	IF @command = 'HF'  
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET HedgeForecast = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END

	-- only select game .. for all bettype [Toggle Deny <match>]
	IF @command = 'TDM' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1	= 1
			,IsTotalBetDenied_3 = 1
			,IsTotalBetDenied_7 = 1
			,IsTotalBetDenied_8 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	
	-- only selected game.. for selected bettype [Toggle Deny <bettype>]
	IF @command = 'TD1' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1 = 1
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END	
	IF @command = 'TD3' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_3 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END	
	IF @command = 'TD7' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_7 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END	
	IF @command = 'TD8' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_8 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END

	-- only selected game.. for paired bettype [Toggle Deny <bettype>]
	IF @command IN ('TP1', 'TP7') 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1	= 1
			,IsTotalBetDenied_7 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END	
	IF @command IN ('TP3', 'TP8') 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_3	= 1
			,IsTotalBetDenied_8 = 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	
	-- only selected game.. for selected bettype [Toggle Allow <bettype>]
	IF @command = 'TA1' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1 = 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END
	IF @command = 'TA3' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_3 = 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END
	IF @command = 'TA7' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_7 = 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	IF @command = 'TA8' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_8 = 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	
	-- only selected game .. for all bettype [Toggle Allow <match>]
	IF @command = 'TAM' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1	= 0
			,IsTotalBetDenied_3 = 0
			,IsTotalBetDenied_7 = 0
			,IsTotalBetDenied_8 = 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	
	-- only selected bettype .. for all games [Toggle Allow All <bettpe>]
	IF @command = 'TAA1' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_1		= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE IsTotalBetDenied_1 = 1
	END
	IF @command = 'TAA3' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_3		= 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE IsTotalBetDenied_3 = 1
	END
	IF @command = 'TAA7' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_7		= 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE IsTotalBetDenied_7 = 1
	END
	IF @command = 'TAA8' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET IsTotalBetDenied_8		= 0
			,RepUpdateTime = SYSDATETIME() 
		WHERE IsTotalBetDenied_8 = 1
	END
	
	-- all bettype, all games [Toggle Allow All Matches]
	IF @command = 'TAAM' 
	BEGIN
		UPDATE match_remark 
		SET IsTotalBetDenied_1	= 0
		,IsTotalBetDenied_3 	= 0
		,IsTotalBetDenied_7 	= 0
		,IsTotalBetDenied_8 	= 0
		,RepUpdateTime = SYSDATETIME()
	END

	-- LiveTimer section , @ivalue will pass adjustment (in seconds) to adjust with CURRENT_TIMESTAMP
	IF @command = 'LP0' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET LivePeriod = 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END
	IF @command = 'LP1' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET LivePeriod	= 1
		,LiveTimer		= DATEADD(second, @ivalue, CURRENT_TIMESTAMP)
		,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END
	IF @command = 'LP2' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET LivePeriod	= 2
		,LiveTimer		= DATEADD(second, @ivalue, CURRENT_TIMESTAMP) 
		,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid
	END
		
	--DELETE FROM match_remark WHERE matchid IN (SELECT matchid FROM match14 with (nolock))

	-- update isPending
	IF @command = 'IsP' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET isPending = @ivalue
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid   
	END
	  
	-- update isUndecided  
	IF @command = 'IsU' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK)
		SET isUndecided = @ivalue
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid	--20120306@Hurri
	END

	-- update SettlementStatus135 status for Penalty Shootout
	--IF @command = 'PS' 
	--BEGIN
	--	UPDATE match_remark WITH (ROWLOCK, UPDLOCK) 
	--	SET SettlementStatus135 = @ivalue
	--	WHERE matchid = @matchid  
	--END

	IF @command = 'VSC' 
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET Calculate		= 1
			,calrefund		= 0
			,IsHTCal		= 1
			,isPending		= 0
			,isUndecided	= 0
			,multiple		= 1
			,refund			= 0
			,RepUpdateTime = SYSDATETIME()
		WHERE matchid = @matchid -- whole match calculated
	END

	IF @command = 'VSR'
	BEGIN
		UPDATE match_remark WITH(ROWLOCK, UPDLOCK) 
		SET calculate		= 0
			,IsHTCal		= 0
			,calrefund		= 1
			,isPending		= 0
			,isUndecided	= 0
			,multiple		= 0
			,refund			= 1
			,RepUpdateTime = SYSDATETIME() 
		WHERE matchid = @matchid
	END

END
GO