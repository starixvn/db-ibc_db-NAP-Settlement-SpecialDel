/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_BetDaq_Checking]
	@matchid				int = 0
AS 

/*
Created: 20120924@dAN
Task : Checking exists betdatd tickets or not
DB: DBTXN/bodb02
Original: [Acc_Set_BetDaq_Checking]

Revisions: 
	-20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
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

Note: For settlement SPs should hardcode the custid of betdaq customer to avoid replication problem
	* List of BetDaq Customers 
			custid	--- username	-	roleid
			1077687	---	BFOS		-	1
			50057	---	BQUS888		-	1
			879241	---	BQUSMLB		-	1
			103873	---	BQUSNBA		-	1
			78761	---	ITibc101	-	1
			1688156	---	MTEST0101	-	2
			851668  --- DUS01		-	1
			878902  --- BDUS016		-	1

Param's Explanation:
• @matchid: matchid of match to checking
• @IsMovebetdaq:
	= 0 don't move betdaq tickets to other match
	= 1 move betdaq tickets to other match
• @IsExcludeBetdaq:
	= 0 hide the checkbox exclude betdaq
	= 1 show the checkbox exclude betdaq
• @IsSettleAbandonedMatch:
	= 0 hide the checkbox "Settle determined tickets"
	= 1 show the checkbox "Settle determined tickets"

• @IsRefundRunningBetDaq:
	= 0 hide the checkbox "Refund running BetDaq"
	= 1 show the checkbox "Refund running BetDaq"

*/
BEGIN
	SET NOCOUNT ON
	DECLARE 
		@IsMovebetdaq			bit ,
		@IsExcludeBetdaq		bit,
		@IsSettleAbandonedMatch bit,
		@IsRefundRunningBetDaq	bit,
		@IsCentral				BIT = 0
		
	SELECT	@IsMovebetdaq = 0, 
			@IsExcludeBetdaq = 0, 
			@IsSettleAbandonedMatch =0 ,
			@IsRefundRunningBetDaq =0 
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF EXISTS (
				SELECT 1 
				FROM bettrans b WITH (NOLOCK) 
					LEFT JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE 
						(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
								OR recommend = 1688156	)
						AND matchid = @matchid 
						AND ruben = 0
						AND b.bettype NOT BETWEEN 1301 AND 1399	-- Sportting solution exclude in Betdaq/Betfair 
						AND b.bettype NOT BETWEEN 153 AND 156		-- Tennis new bet types 
						AND f.IsAuto = 0
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			   )
	BEGIN
		SELECT	@isMoveBetDaq = 1, @isExcludeBetDaq = 1, @IsRefundRunningBetDaq = 1  	
	END


	IF EXISTS (
				SELECT 1 
				FROM bettrans b WITH (NOLOCK) 
					INNER JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE 
						(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
							OR recommend = 1688156	)
						AND matchid = @matchid 
						AND f.IsDetermined = 1
						AND f.IsAuto = 0
						AND statusID NOT IN (101, 102, 103)
						AND ruben = 0 
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			   )
	BEGIN
		SELECT	@IsSettleAbandonedMatch = 1 

	END
	SELECT @IsMovebetdaq IsMovebetdaq,
		@IsExcludeBetdaq IsExcludeBetdaq,
		@IsSettleAbandonedMatch IsSettleAbandonedMatchBetdaq,
		@IsRefundRunningBetDaq	IsRefundRunningBetDaq
	
END
GO