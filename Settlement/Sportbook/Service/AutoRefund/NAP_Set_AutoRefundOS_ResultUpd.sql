/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefundOS_ResultUpd
  @MatchId		 INT	 
 ,@TypeId		 TINYINT		= 1
 ,@StatusId		 TINYINT  		
 ,@ResourceIds	 VARCHAR(500)
 ,@Remark		 VARCHAR(1000)  = NULL
 ,@TryCount		 TINYINT = 0
AS

/*
	Creator: 20220512@Louisa
	Task: Auto refund Badminton [Redmine:#171676]
	DB: DBPRO/bodb02

	Revisions:
		- 20220512@Louisa: Initial 
		- 20230104@Kathy: Add @trycount [Redmine:#181458]
		
	Param's explaination:
		@ResourceIds = '0103,0104,0105'
*/
BEGIN
	SET NOCOUNT ON

	IF @TypeId = 1
	BEGIN
		UPDATE r
			SET 
				StatusId	=  @StatusId
				,TryCount	= @TryCount			
				,ModifiedDate	= GETDATE()
				,Remark			= COALESCE(@Remark, Remark)
		FROM dbo.AutoRefundResultOS r WITH(ROWLOCK,UPDLOCK)
			INNER JOIN STRING_SPLIT(@ResourceIds, ',') f 
				ON r.ResourceID  = f.value
		WHERE SourceId = 105 --Auto Refund
			AND TypeId = @TypeId
			AND MatchId = @MatchId

	END

END
GO