/*<info serverAlias="DBCONSISTENCY-bodb_Consistency" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCONSISTENCY-bodb_Consistency
	
	Revisions:
		- 20230626@Louisa: Update Max SequenceID for job dectect data consistency rule #55  [Redmineid:#181595] 

*/

USE bodb_Consistency 
GO

	DECLARE @maxSequenceId_bettrans BIGINT
			, @maxSequenceId_bettransLC BIGINT
			, @maxSequenceId_bettransG BIGINT
			, @maxSequenceId_bettransRnG BIGINT
			, @maxSequenceId_translog BIGINT

	SELECT	@maxSequenceId_bettrans = MAX(sequenceid)
	FROM	bodb02.dbo.bettrans WITH (NOLOCK)

	SELECT	@maxSequenceId_bettransLC = MAX(sequenceid)
	FROM	bodb02.dbo.bettransLC WITH (NOLOCK)

	SELECT	@maxSequenceId_bettransG = MAX(sequenceid)
	FROM	bodb02.dbo.bettransG WITH (NOLOCK)

	SELECT	@maxSequenceId_bettransRnG = MAX(sequenceid)
	FROM	bodb02.dbo.bettransRnG WITH (NOLOCK)

	SELECT	@maxSequenceId_translog = MAX(sequenceid)
	FROM	bodb02.dbo.translog WITH (NOLOCK)

	UPDATE dbo.DBA_SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET VValue = ISNULL(@maxSequenceId_bettrans,0)
	WHERE VName = 'DiffSGId_LastSeqId_bettrans'

	UPDATE dbo.DBA_SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET VValue = ISNULL(@maxSequenceId_bettransLC,0)
	WHERE VName = 'DiffSGId_LastSeqId_bettransLC'

	UPDATE dbo.DBA_SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET VValue = ISNULL(@maxSequenceId_bettransG,0)
	WHERE VName = 'DiffSGId_LastSeqId_bettransG'

	UPDATE dbo.DBA_SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET VValue = ISNULL(@maxSequenceId_bettransRnG,0)
	WHERE VName = 'DiffSGId_LastSeqId_bettransRnG'

	UPDATE dbo.DBA_SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET VValue = ISNULL(@maxSequenceId_translog,0)
	WHERE VName = 'DiffSGId_LastSeqId_translog'
