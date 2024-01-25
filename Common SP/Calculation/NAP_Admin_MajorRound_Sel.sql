/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_MajorRound_Sel]
	@Sporttype SMALLINT
AS
/*
	Creator: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
	DB: DBPRO/bodb02
	Revisions:
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	SELECT   Sporttype
			,RoundID
			,RoundName
			,ResourceID
			,GroupType
			,isFinal
			,OrdNo
			,AllowDirectly
			,IntervalNo 
	FROM dbo.f_Set_MajorRound(@Sporttype)
END
GO