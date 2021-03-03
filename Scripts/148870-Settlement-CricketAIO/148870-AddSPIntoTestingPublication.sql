/*<info serverAlias="DBTXN-bodb02,SITDB042-bodb02,SITDB044-bodb02,SITDB05-bodb02,SITDB052-bodb02,SITDB055-bodb02,SITDB05BK1-bodb02,SITDB06-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb02
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT1
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: publication: DBTrans_ExecRep_UAT

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
*/
BEGIN
	SET NOCOUNT ON
	
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT2
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON
	
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT3
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON
	
END
GO