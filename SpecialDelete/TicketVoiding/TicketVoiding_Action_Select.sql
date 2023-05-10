/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Action_Select]
	  
AS
/*	Created by: Kathy
	Date 20181212
	Task: get all actions [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20210305@July: [TVS] Auto void before KO time - [Redmine: #150522]
		- 20210820@July: [TVS] Add new status Void Instant without any policy - [Redmine: #160012]

	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN
		SELECT 	ActionId 
				,ActionName
		FROM 	[dbo].[TicketVoiding_Action] WITH(NOLOCK)
		ORDER BY CASE WHEN ActionName = 'Auto Void Winning' THEN '1'
					  WHEN ActionName = 'Auto Void All (Instant)' THEN '2'
					  WHEN ActionName = 'Auto Void All (Instant w/o Policy)' THEN '3'
			          WHEN ActionName = 'Auto Void All (5m before KO)' THEN '4'
				      WHEN ActionName = 'Auto Void All (10m before KO)' THEN '5'
				      WHEN ActionName = 'Manual Void' THEN '6'
				      ELSE ActionName 
				 END
	END
END
GO