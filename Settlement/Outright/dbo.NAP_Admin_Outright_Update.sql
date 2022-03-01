/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Outright_Update]
	 @MatchID		INT
	,@Status		NVARCHAR(10)
	,@Action		VARCHAR(10)		='CAL'	
	,@EventDate		DATETIME		= NULL
	,@isDeadheat	BIT				= 0 
	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		NVARCHAR(200)	= '' OUTPUT
AS
/*
	Created by: Jamie
	Date: 2014-08-11
	Task: Settlement Outright 
	DB: DBPRO/bodb02 
	Original: Dot_Admin_SettleOutright_Event 
	
	Revision: 
		- 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393] 

	Param's Explanation:
		+ @Action	= CAL | UNDO | REFUND
		+ @Deadheat = fraction of deadheat to divide (1,2,3  etc)	
*/

BEGIN
	SET NOCOUNT ON 

	IF @Action ='UNDO'
	BEGIN
		Update Outright WITH (UPDLOCK,ROWLOCK)
		SET		oddsstatus	= 'Running'
				,status		= NULL
				,changetime = GETDATE()
		WHERE Orid = @MatchID 
	END

END 
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Outright_Update] TO [bodbAdminNet] 
GO 