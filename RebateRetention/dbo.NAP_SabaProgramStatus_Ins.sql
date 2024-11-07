/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SabaProgramStatus_Ins]
	  @ProgramId	SMALLINT	
	 ,@IsTest		BIT = 0
	 ,@SId			INT		OUTPUT					
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

	INSERT INTO SabaProgramStatus(ProgramId,SiteDBGroupId,StatusId,IsNotified,CreatedDate,RepUpdateTime,IsTest)
	SELECT @ProgramId,dbo.f_Get_SiteDBGroupID(),1,0,GETDATE(),SYSDATETIME(),@IsTest

	SET @SId = SCOPE_IDENTITY(); 

END