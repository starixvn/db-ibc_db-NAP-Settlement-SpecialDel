/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/


DECLARE @SessionId		BIGINT = 0
		,@MessageId		VARCHAR(128) = ''
		,@SiteDBGroupId SMALLINT


/*
 For parallel process, use parameter @SessionId to Update
 For Non-parallel process , use parameter @MessageId to Update

*/

	---For parallel process, use parameter @SessionId to Update
	IF ISNULL(@SessionId, 0) > 0
	BEGIN
		UPDATE s 
			SET Resolved = 1
		FROM	dbo.SSB_SettlementLogs s WITH(ROWLOCK, UPDLOCK)
		WHERE	s.sessionId = @SessionId
				AND SiteDBGroupId =  @SiteDBGroupId
				AND ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
	END

	-- For Non-parallel process , use parameter @MessageId to Update
	ELSE IF ISNULL(@MessageId, '') <> ''
	BEGIN
		UPDATE s 
			SET Resolved = 1
		FROM	dbo.SSB_SettlementLogs s WITH(ROWLOCK, UPDLOCK)
		WHERE	s.MessageId = @MessageId
				AND SiteDBGroupId =  @SiteDBGroupId
				AND ISNULL(ErrorMessage,'') <> ''
				AND Resolved = 0
	END
