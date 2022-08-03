/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_BetFair_Checking] 
	@matchid INT = 0
AS
/*
Created: 20140113@Kathy
Task : Checking exists betfair tickets or not [Redmine:#9007]
DB: DBTXN/bodb02
Original: Acc_Set_BetFair_Checking

Revisions: 
	-20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
	-20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
	-20140707@Kathy: Execute settlement for abandoned/postponed matches: BetRadar [Redmine:17142]
	-20140725@Kathy: Execute settlement for abandoned/postponed matches: Correct Score(4,30)[Redmine:#19310]
	-20140811@Kathy: Support new 11 bettypes [Redmine:#19667]
	-20141023@Jamie: Exclude new bet types Sporting Solution for Tennis [Redmine:#23034] 
	- 20150418@Jamie: Betradar phase II [Readmine:#27212]
	- 20151215@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
	- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
	- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
	- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
	- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

Note: For settlement SPs should hardcode the custid of betfair customer to avoid replication problem
	* List of Betfair Customers 
			custid	--- username	-	roleid
			2331	---	BF		    -	1
			1077687	---	BFOS		-	1
			15523642--- BF3			-	1

Param's Explanation:
• @matchid: matchid of match to checking
• @IsMovebetfair:
	= 0 don't move betfair tickets to other match
	= 1 move betfair tickets to other match
• @IsExcludeBetfair:
	= 0 hide the checkbox exclude betfair
	= 1 show the checkbox exclude betfair
• @IsSettleAbandonedMatchBetfair:
	= 0 hide the checkbox "Settle determined tickets"
	= 1 show the checkbox "Settle determined tickets"
• @IsRefundRunningBetfair:
	= 0 hide the checkbox "Refund running BetFair"
	= 1 show the checkbox "Refund running BetFair"

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsMovebetfair BIT
		,@IsExcludeBetfair BIT
		,@IsSettleAbandonedMatchBetfair BIT
		,@IsRefundRunningBetfair BIT
		,@IsCentral	BIT = 0

	SELECT @IsMovebetfair = 0
		,@IsExcludeBetfair = 0
		,@IsSettleAbandonedMatchBetfair = 0
		,@IsRefundRunningBetfair = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF EXISTS (
			SELECT 1
			FROM bettrans b WITH (NOLOCK)
				LEFT JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
			WHERE	custid IN (2331, 1077687, 115770, 15523642) 
					AND matchid = @matchid 
					AND ruben = 0
					AND f.bettype NOT BETWEEN 1301 AND 1399	-- Sportting solution exclude in Betdaq/Betfair 
					AND f.bettype NOT BETWEEN 153 AND 156		-- Tennis new bet types
					AND f.IsAuto = 0
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			)
	BEGIN
		SELECT @IsMovebetfair = 1
			,@IsExcludeBetfair = 1
			,@IsRefundRunningBetfair = 1
	END

	IF EXISTS (
			SELECT 1
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
			WHERE custid IN (2331, 1077687, 115770, 15523642) 
			AND matchid = @matchid 
			AND f.IsDetermined = 1
			AND f.IsAuto = 0
			AND statusID NOT IN (101, 102, 103) 
			AND ruben = 0
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
	BEGIN
		SELECT @IsSettleAbandonedMatchBetfair = 1

	END

	SELECT @IsMovebetfair AS IsMovebetfair
		,@IsExcludeBetfair AS IsExcludeBetfair
		,@IsSettleAbandonedMatchBetfair AS IsSettleAbandonedMatchBetfair
		,@IsRefundRunningBetfair AS IsRefundRunningBetfair
END
GO