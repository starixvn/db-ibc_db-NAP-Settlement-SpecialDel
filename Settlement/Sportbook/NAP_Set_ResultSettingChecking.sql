/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ResultSettingChecking
	@MatchId	INT
	,@Action	VARCHAR(20)
	,@IsAuto	BIT = 0
	,@SelectedResources VARCHAR(MAX) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(200) = '' OUTPUT
AS
/*
	Created by: 20210811@Louisa
	Task	: Check Confirm Refund setting [Redmine:#159270]
	DB		: DBPRO/bodb02

	Revisions:
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192] 
		- 20210925@Helen: Nap Settlement - Cricket - Cannot refund due to selected results are not confirmed to refund - [162244]
		- 20210906@Louisa: SOP Refund for Volleyball, Beach Volleyball [Redmine:#160478]
		- 20211025@Louisa: SOP Refund for Badminton, Basketball, Cricket [Redmine:#163574]
		- 20211127@Helen: Settlement - The Volleyball match cannot key refund. [Redmine:#165296]
		- 20220406@Louisa: Cannnot Refund child match Cricket ( childMatchType = 200) [Redmine:#171188]
		- 20220512@Louisa: Auto Refund for Badminton [Redmine:#171676]
		- 20220629@Louisa: Change rule confirm Refund: confirm [Redmineid:#173862]
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20221213@Kathy: Upgrade Auto Payout for Badminton & Volleyball [Redmine:#181458]
		- 20230214@Louisa: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]

	Param's Explanation:
		  @SelectedResources: <Resources>
						    	<Resource Id="M1" Home="1" Away="3" />
						    	<Resource Id="M2" Home="2" Away="4" />
						      </Resources>
*/
BEGIN
	SET NOCOUNT ON


	DECLARE @Sporttype		SMALLINT
			,@handle		INT
			,@ResultTable	TINYINT	= 0


	DECLARE @tmpResourceID	  TABLE ( ResourceID VARCHAR(20) )
	DECLARE @tmpResultSetting TABLE ( ResultSetting VARCHAR(20) )

	SELECT @Sporttype	= m.Sporttype
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

	SELECT @ResultTable = r.ResultTable
	FROM dbo.SettlementResultTableSetting r WITH(NOLOCK) 
	WHERE r.Sporttype = @SportType
	
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpResourceID(ResourceID)
	SELECT DISTINCT Id	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20) ) AS tbl
	EXEC sp_xml_removedocument @handle

	IF @Sporttype = 45
	BEGIN
		DELETE @tmpResourceID WHERE ResourceID <> '00'
	END

	IF @ResultTable = 1
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT ISNULL(r.ResultSetting,0)
		FROM dbo.ResultDetail r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END
	
	IF @ResultTable = 2
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT ISNULL(r.ResultSetting,0)
		FROM dbo.ResultDetailOS r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END

	IF @ResultTable = 3
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT ISNULL(r.ResultSetting,0)
		FROM dbo.ResultDetailES r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END
	
	IF @Action  LIKE 'Refund%'
	BEGIN
		IF ( SELECT COUNT(1) FROM @tmpResultSetting ) = 0
			OR EXISTS (SELECT TOP 1 1 FROM @tmpResultSetting r WHERE r.ResultSetting & 2 = 0 )
		
		SELECT @ErrCode = 1001055
			 , @ErrMsg	= 'WARNING! Cannot continue due to selected results are not confirmed to refund. Please confirm refund and try again.'
	END
	ELSE IF @Action LIKE 'CAL%'
		SELECT @ErrCode = 1001056
			 , @ErrMsg  = 'WARNING! Cannot continue due to selected results are confirmed to refund. Please undo-confirm refund and try again.'
		FROM @tmpResultSetting r WHERE r.ResultSetting & 2 = 2
END
GO