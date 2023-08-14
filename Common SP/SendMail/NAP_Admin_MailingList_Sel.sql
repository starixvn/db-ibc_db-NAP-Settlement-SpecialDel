/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_MailingList_Sel
	@SportType			TINYINT
	,@GroupName			VARCHAR(50)

AS
/*	
	Creator: 20230704@Louisa 
	Task: Virtual Leap Gaming - VS3
	DB: DBTXN/bodb02 
	
	Revisions:
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]
 
*/
BEGIN
	DECLARE @CreditRecipients 	VARCHAR(500) = '' 
			,@DepositRecipients VARCHAR(500) = ''	 
			,@CopyRecipients	VARCHAR(500) = ''  --cc list 

	IF @SportType = 178
	BEGIN
		SELECT	@CopyRecipients		= Recipients
				,@CreditRecipients 	= Credit_Recipients
				,@DepositRecipients = Deposit_Recipients
		FROM [dbo].[f_Set_VS_BetRadar_EmailConfig] ()
		WHERE GroupName = @GroupName
	END

	SELECT @CreditRecipients 	AS CreditRecipients
		   ,@DepositRecipients  AS DepositRecipients
		   ,@CopyRecipients		AS CopyRecipients
END	
GO