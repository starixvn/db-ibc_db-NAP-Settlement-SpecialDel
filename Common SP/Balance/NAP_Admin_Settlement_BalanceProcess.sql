/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_BalanceProcess
(
	@BalanceAcc				VARCHAR(MAX)
	, @BalanceType			TINYINT =  1
	, @ActionId				INT = 0
	, @MatchID				INT = 0
	, @GroupID				INT = 0
)
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20230523@Kathy: remove un-used table [Redmine:#188452]
		
	Param's Explanation:
		- @BalanceType: Balance Type [1: Sports, 3: Casino, 4: Others]
		- @MatchID: Event match ID
		- @ActionId: Action Log Id
		- @GroupID: Negative balance group ID
*/	
BEGIN
	SET NOCOUNT ON
	
	IF(LEN(ISNULL(@BalanceAcc,'')) = 0) RETURN	
	
	DECLARE @xmlBalance		XML
	
	DECLARE @beforeUpd 		TVP_BalanceChange 
		, @afterUpd			TVP_BalanceChange 
	
	--Tracing balance table
	DECLARE @custBalanceUpd TABLE (custid INT, balanceBefore MONEY, balanceAfter MONEY)			
	
	--CONVERT XML
	SET @xmlBalance = CONVERT(XML, @BalanceAcc)
	
	INSERT INTO @custBalanceUpd (custid, balanceBefore, balanceAfter)	
	SELECT T.C.value('./@c', 'INT') AS custid
		, T.C.value('./@b', 'MONEY') AS balanceBefore
		, T.C.value('./@a', 'MONEY') AS balanceAfter
	FROM @xmlBalance.nodes('/r') as [T](C) --T: table, C: column	
	OPTION (OPTIMIZE FOR (@xmlBalance = NULL))			
	
	--CAPTURE pending balance before
	INSERT INTO @beforeUpd (
		custid
		,balance
		,balanceType
	)
	SELECT b.custid
		,SUM(b.balanceBefore) AS balance
		,@BalanceType
	FROM @custBalanceUpd AS b
	GROUP BY b.custid
	
	--CAPTURE pending balance after
	INSERT INTO @afterUpd (
		custid
		,balance
		,balanceType
	)
	SELECT a.custid
		,SUM(a.balanceAfter) AS balance
		,@BalanceType
	FROM @custBalanceUpd AS a
	GROUP BY a.custid
	
	---INSERT data into pending balance table   
	IF(EXISTS (SELECT 1
		FROM @beforeUpd b
			INNER JOIN @afterUpd a
			ON b.custid = a.custid
		WHERE b.balance <> a.balance)
	)
	BEGIN
		
		--UPDATE pending table balance
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			@BeforeUpd	 = @beforeUpd
			, @AfterUpd	 = @afterUpd
	
		----
		-- Add Negative Balance into BalanceNegative table 
		----
		IF(@ActionID > 0 AND @MatchID > 0 AND @GroupID > 0) AND OBJECT_ID('BalanceNegative','U') IS NOT NULL
		BEGIN
			INSERT INTO [dbo].[BalanceNegative] (
				[ExecDate]
				,[MatchID]
				,[ActionID]
				,[GroupID]
				,[CustID]
				,[Balance]
				,[StatusID]
				,[Remark]
				)
			SELECT GETDATE()
				,@MatchID
				,@ActionID
				,@GroupID -- Negative balance group
				,a.CustID
				,a.balance - b.balance AS Balance
				,0
				,NULL
			FROM @afterUpd a
				INNER JOIN @beforeUpd b
				ON a.custid = b.custid
			WHERE a.balance < b.balance 
		END
	END
END
GO