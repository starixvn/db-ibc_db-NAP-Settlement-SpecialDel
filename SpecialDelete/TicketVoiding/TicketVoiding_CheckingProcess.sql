/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckingProcess]
(
	@MatchId			INT = NULL
	, @KeyID			INT = 1
	, @IsExistSingle	BIT = 1
	, @IsExistParlay	BIT = 0
	, @ErrCode			INT = 0 OUTPUT
	, @ErrMsg			NVARCHAR(200) = '' OUTPUT
)	  
AS
/*	Created by: Max
	Date 20200528
	Task: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200528@Max: Create new SP - [Redmine: #134269]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	IF (@IsExistSingle = 1)
	BEGIN
		IF EXISTS(SELECT 1
				FROM dbo.TempVariableNumber ck WITH(ROWLOCK)
				WHERE ck.KeyID = @KeyID 
					AND ck.KeyValue = @MatchId
				)
		BEGIN
			SELECT @ErrCode = 103
					,@ErrMsg	= 'This match is being calculated or some tickets of this match are being deleted, please wait a few seconds until the on-going process is completed and try again.'
				 
			RETURN;
		END
	END

	IF (@isExistParlay  = 1)
	BEGIN
		IF EXISTS(SELECT 1 
				FROM dbo.SystemSettings WITH (NOLOCK)
				WHERE VValue 	= 1 
				AND VName 		= 'isCalculatingParlay'
		)  
		BEGIN  
			SELECT @ErrCode	= 100  
				,@ErrMsg 	= 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'  
				
			RETURN;
		END
	END
END
GO