/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_2] 
	@betstatus 			NVARCHAR(50) = NULL
	,@Total 			INT = NULL OUTPUT
	,@TotalHome 		INT = NULL OUTPUT
	,@TotalAway 		INT = NULL OUTPUT
	,@mode 				VARCHAR(30) = 'tennis' --tennis, cornersBets, betRadar, sporttingSolution, basketball
	,@matchid 			INT = NULL
	,@resourceid 		VARCHAR(MAX) = NULL
	,@str_resultDetail 	VARCHAR(MAX) = NULL OUTPUT
	,@Sporttype			SMALLINT	 = 0
AS
/*	Creator: Kathy
	Date: 20140213
	Task: check for Tennis total game played, for calculate of Over/Under, Odd/Even
	DB: DBTXN/BODB02
	Original: Admin_Settlement_1
	
	Revisions:
		- 20151013@Viet: support sporting solution & betradar
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]	
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190620@Kathy: Remove betradar corner, auto betradar bettypes [Redmine:#109584]
		- 20190924@Sol: Incorporate BMAIO [Redmine:#120324]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		
	Param's Explanation:
		+ @betstatus: Used for score table, FGLG status, refund status
		+ @resourceid: ,1,2,3,20,
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @temp_resultDetail as TABLE (rID varchar(20) PRIMARY KEY, H varchar(50), A varchar(50), ssID tinyint)

	IF @mode = 'tennis'
	BEGIN
		DECLARE @xml XML = CONVERT(XML, N'<root><r h="' + REPLACE(REPLACE(@betstatus, '-', '" a="'), ',', '"/><r h="') + '"/></root>')
	
		SELECT @TotalHome = SUM(ISNULL(T.C.value('./@h', 'tinyint'),0))
			,@TotalAway = SUM(ISNULL(T.C.value('./@a', 'tinyint'),0))
			,@Total = @TotalHome + @TotalAway
		FROM @xml.nodes('/root/r') AS T(C)
		--OPTION (OPTIMIZE FOR (@xml = NULL))
	END -- end tennis	
	
	IF @mode = 'basketball' or @mode = 'all'
	BEGIN
		SET @str_resultDetail = CONVERT(VARCHAR(MAX),(
		SELECT	ResourceId '@rid'
				,HomeValue '@home'
				,AwayValue '@away'
				,SettlementStatusID '@ssId'
		FROM DBPRO.bodb02.dbo.ResultDetail  WITH(ROWLOCK)
		WHERE	matchid = @matchid
				AND SettlementStatusId > 0
		FOR XML PATH('r'), ROOT('root'), TYPE))		
	END
	
	
	IF @mode ='all_profile'
	BEGIN
		IF @Sporttype = 43
			SELECT	ResourceId 
					,HomeValue
					,AwayValue
					,SettlementStatusID AS ssId
			FROM DBPRO.bodb02.dbo.ResultDetailES  WITH(ROWLOCK)
			WHERE	matchid = @matchid
					AND SettlementStatusId > 0
		ELSE IF @Sporttype = 9
			SELECT	ResourceId 
					,HomeValue
					,AwayValue
					,SettlementStatusID AS ssId
			FROM DBPRO.bodb02.dbo.ResultDetailOS  WITH(ROWLOCK)
			WHERE	matchid = @matchid
					AND SettlementStatusId > 0
		ELSE
			SELECT	ResourceId
					,HomeValue
					,AwayValue
					,SettlementStatusID
			FROM DBPRO.bodb02.dbo.ResultDetail  WITH(ROWLOCK)
			WHERE	matchid = @matchid
					AND SettlementStatusId > 0
	END

	
	IF @mode = 'resourceid_profile'
	BEGIN
		IF @Sporttype = 43
		BEGIN
			SELECT	ResourceId
					,HomeValue
					,AwayValue
					,SettlementStatusID AS ssId
			FROM DBPRO.bodb02.dbo.ResultDetailES  WITH (ROWLOCK)
			WHERE	matchid = @matchid
					AND @resourceid LIKE '%,' + ResourceID + ',%'
		END
		ELSE IF @Sporttype = 9
		BEGIN
			SELECT	ResourceId
					,HomeValue
					,AwayValue
					,SettlementStatusID AS ssId
			FROM DBPRO.bodb02.dbo.ResultDetailOS  WITH (ROWLOCK)
			WHERE	matchid = @matchid
					AND @resourceid LIKE '%,' + ResourceID + ',%'
		END
		ELSE
		BEGIN
			SELECT	ResourceId
					,HomeValue
					,AwayValue
					,SettlementStatusID AS ssId
			FROM DBPRO.bodb02.dbo.ResultDetail  WITH (ROWLOCK)
			WHERE	matchid = @matchid
					AND @resourceid LIKE '%,' + ResourceID + ',%'
		END
	END
END
GO