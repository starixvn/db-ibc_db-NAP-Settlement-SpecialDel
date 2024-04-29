/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_CustLimitBetQueue_Insert_Parlay]
(
	@TransIds	VARCHAR(MAX) = NULL
)
AS
/*	
	Created: 20240429@Max
    Task: Enhance the MaxPayout for the Parlay Settlement [Redmine: #204464]
    DB: DBTXN/bodb02
    Revisions:
		- 20240429@Max: Create SP [Redmine: #204464]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
	SELECT 29, @TransIds, 6, 0, GETDATE()

END
GO
	