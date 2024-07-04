/*<info serverAlias="DBTP-bodb_CustHistory" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE ServiceTransform_DestConfig_Select
	@GroupID SMALLINT
AS
/*
	 Created by: 20240628@Louisa
	 Task: init [Redmine:#204370]
	 DB: DBTP-bodb02

	 Revision:
		- 20240628@Louisa: Initial [Redmine:#204370]
*/
BEGIN
	SELECT Tablename
			,rID
			,Interval
			,BatchSize
			,SPSelect
			,SPInsert
	FROM Dest_ServiceTransform WITH(NOLOCK)
	WHERE StatusID = 1
		AND GroupID = @GroupID
END
GO
