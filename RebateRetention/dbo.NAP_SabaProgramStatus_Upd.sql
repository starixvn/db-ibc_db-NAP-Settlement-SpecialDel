/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SabaProgramStatus_Upd]				
	 @SId			SMALLINT 	
	,@StatusId		TINYINT = NULL
	,@IsNotified	BIT		= NULL
AS
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation:  					
*/
BEGIN	
	SET NOCOUNT ON

	UPDATE SabaProgramStatus
	SET  StatusId	 = ISNULL(@StatusId,StatusId)
		,IsNotified	 = ISNULL(@IsNotified,IsNotified)
	WHERE SId = @SId

END