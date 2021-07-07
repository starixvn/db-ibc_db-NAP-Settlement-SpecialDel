/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE NAP_Set_LetstalkMessage_Insert
(
	@MessageGroupId	TINYINT			= 0,
	@MatchId		INT, 
	@ActionId		INT				= 0,	
	@MessageContent	VARCHAR(MAX),
	@UserID			INT, 		
	@IP				VARCHAR(15)		= '',	
	@ErrCode		INT 			= 0 OUTPUT,	
	@ErrMsg			NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Insert Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Insert Letstalk message [Redmine:#157540]

	Param explanation:
		@MessageType 
					1: Instant Settlement
		@ActionId: 
					101: Cal Inst HT
					102: Cal Inst FT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ActionName		NVARCHAR(512) = ''
			,@kickofftime	DATETIME
			,@leaguename		NVARCHAR(1000)
			,@HomeName		NVARCHAR(200)
			,@AwayName		NVARCHAR(200)

	SELECT @ActionName =  l.ActionNameEN 
	FROM dblog.bodb_customerlog.dbo.LogAction l WITH(NOLOCK)
	WHERE l.ActionID = @ActionId

	SELECT @leaguename = l.LeagueName
			,@HomeName = home.teamname
			,@AwayName = away.teamname
			,@kickofftime = m.kickofftime
	FROM dbo.match m WITH(NOLOCK)
	INNER JOIN dbo.League l WITH(NOLOCK)
		ON m.leagueid = l.leagueid
	LEFT JOIN dbo.team home WITH(NOLOCK)
		ON m.homeid = home.teamid
	LEFT JOIN dbo.team away WITh(NOLOCK)
		ON m.awayid = away.teamid
	WHERE m.matchid = @MatchId

	BEGIN TRY
		INSERT INTO [dbo].[Settlement_LetstalkMessage]
		(	
			 MessageGroupId		
			,MatchId			
			,kickofftime		
			,ActionId		
			,ActionName		
			,leaguename		
			,HomeName		
			,AwayName		
			,MessageContent	
			,StatusId		
			,CreateDate		
			,CreateBy		
			,LastModifyDate	
			,LastModifyBy		
			,IP
		) 
		SELECT	
			@MessageGroupId
			,@MatchId
			,@kickofftime
			,@ActionId
			,@ActionName
			,@leaguename
			,@HomeName
			,@AwayName
			,@MessageContent
			,0
			,GETDATE()
			,@UserID
			,GETDATE()
			,@UserID
			,@IP

	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			, @ErrMsg = ISNULL(ERROR_MESSAGE(), '')
	    RETURN
    END CATCH   

END
GO
