/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20201005@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/bodb02

	Revision:
		- 20201005@Louisa: insert value 'JobDeploymentDate' into SystemSettings

*/

USE [bodb02]
GO


IF NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[SystemSettings] WITH(NOLOCK) WHERE VName = 'JobDeploymentDate' )
BEGIN
	INSERT INTO [dbo].[SystemSettings] ([VName] )
	SELECT 'JobDeploymentDate'
END
GO
