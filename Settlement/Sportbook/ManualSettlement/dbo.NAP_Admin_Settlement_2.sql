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

	IF @mode = 'sporttingSolution'
	BEGIN		
		INSERT INTO @temp_resultDetail(rID, H, A, ssID)
		SELECT resourceID, homeValue, awayValue, SettlementStatusID
		FROM DBPRO.bodb02.dbo.ResultDetail WITH(NOLOCK)
		WHERE MatchID = @MatchID
			AND SettlementStatusID > 0 
			AND ResultStatusID = 5 -- Score from Settlement Site 

		DECLARE @h int, @a int, @gameHomeSet_bin binary(5), @gameAwaySet_bin binary(5)
		DECLARE @SetxGameyHomeWON varchar(max) = ''
		DECLARE @SetxGameyAwayWON varchar(max) = ''
		DECLARE @SetxGameyDRAW varchar(max) = ''
		DECLARE @SetxGameyREFUND varchar(max) = ''
		DECLARE @SetxGameyFinishedGame varchar(max) = ''
		DECLARE @SelectedSetCAL varchar(50) = ''
		DECLARE @SelectedSetREFUND varchar(50) = ''
		
		SELECT @TotalHome = 0, @TotalAway = 0, @Total = 0
		
		SELECT @h = CASE H WHEN 'A' THEN 65 ELSE CAST(H AS int) END
			,@a = CASE A WHEN 'A' THEN 65 ELSE CAST(A AS int) END
			,@SetxGameyHomeWON		+= CASE WHEN rID LIKE '0[1-5][0-9][0-9]' AND ssID = 4 AND @h > @a THEN rID +',' ELSE '' END
			,@SetxGameyAwayWON		+= CASE WHEN rID LIKE '0[1-5][0-9][0-9]' AND ssID = 4 AND  @h < @a THEN rID +',' ELSE '' END
			,@SetxGameyDRAW			+= CASE WHEN rID LIKE '0[1-5][0-9][0-9]' AND ssID = 4 AND @h = @a THEN rID +',' ELSE '' END
			,@SetxGameyREFUND		+= CASE WHEN rID LIKE '0[1-5][0-9][0-9]' AND ssID = 1 THEN rID +',' ELSE '' END
			,@SetxGameyFinishedGame	+= CASE WHEN rID LIKE '0[1-5][0-9][0-9]' AND ssID = 4 THEN rID +',' ELSE '' END		
			,@SelectedSetCAL		+= CASE WHEN rID LIKE '0[0-5]' AND ssID = 4 THEN REPLACE(RIGHT(rID,1), '0', '6') ELSE '' END
			,@SelectedSetREFUND		+= CASE WHEN rID LIKE '0[0-5]' AND ssID = 1 THEN REPLACE(RIGHT(rID,1), '0', '6') ELSE '' END
			,@TotalHome += CAST(CASE WHEN rID LIKE '0[1-5]' THEN ISNULL(H,0) ELSE 0 END AS INT)
			,@TotalAway += CAST(CASE WHEN rID LIKE '0[1-5]' THEN ISNULL(A,0) ELSE 0 END AS INT)
		FROM @temp_resultDetail
		WHERE rID LIKE '0[0-5]%'
		
		SET @Total = @TotalHome + @TotalAway
		
		SET @str_resultDetail = CONVERT(VARCHAR(MAX), (
			SELECT '@homeScoreSet1' 		= NULLIF(MAX(CASE WHEN rID ='01' THEN ISNULL(H,0) ELSE 0 END),0)
				,'@homeScoreSet2' 			= NULLIF(MAX(CASE WHEN rID ='02' THEN ISNULL(H,0) ELSE 0 END),0)
				,'@homeScoreSet3' 			= NULLIF(MAX(CASE WHEN rID ='03' THEN ISNULL(H,0) ELSE 0 END),0)
				,'@homeScoreSet4' 			= NULLIF(MAX(CASE WHEN rID ='04' THEN ISNULL(H,0) ELSE 0 END),0)
				,'@homeScoreSet5' 			= NULLIF(MAX(CASE WHEN rID ='05' THEN ISNULL(H,0) ELSE 0 END),0)
				,'@awayScoreSet1' 			= NULLIF(MAX(CASE WHEN rID ='01' THEN ISNULL(A,0) ELSE 0 END),0)
				,'@awayScoreSet2' 			= NULLIF(MAX(CASE WHEN rID ='02' THEN ISNULL(A,0) ELSE 0 END),0)
				,'@awayScoreSet3' 			= NULLIF(MAX(CASE WHEN rID ='03' THEN ISNULL(A,0) ELSE 0 END),0)
				,'@awayScoreSet4' 			= NULLIF(MAX(CASE WHEN rID ='04' THEN ISNULL(A,0) ELSE 0 END),0)
				,'@awayScoreSet5' 			= NULLIF(MAX(CASE WHEN rID ='05' THEN ISNULL(A,0) ELSE 0 END),0)				
				,'@SetxGameyHomeWON'		= NULLIF(@SetxGameyHomeWON,'')
				,'@SetxGameyAwayWON'		= NULLIF(@SetxGameyAwayWON,'')
				,'@SetxGameyDRAW'			= NULLIF(@SetxGameyDRAW,'')
				,'@SetxGameyREFUND'			= NULLIF(@SetxGameyREFUND,'')
				,'@SetxGameyFinishedGame'	= NULLIF(@SetxGameyFinishedGame,'')
				,'@SelectedSetCAL'			= NULLIF(@SelectedSetCAL,'')
				,'@SelectedSetREFUND'		= NULLIF(@SelectedSetREFUND,'')
			FROM @temp_resultDetail
			WHERE ssID = 4
				AND rID LIKE '0[1-5]'
			FOR XML PATH('r'), ROOT('root'), TYPE
		))		
	END -- end sporttingSolution
	
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