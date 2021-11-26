/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_MsgSent @MessageContent nvarchar(max)
	,@ConversationHandle uniqueidentifier
	,@MessageType varchar(200)
	,@ErrorCode	int = 0  output
	,@ErrorMessage varchar(max)	= '' output

as
/*  Created: Patrick@20210801
	Task: Send message
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on
	begin try
		;send on conversation @ConversationHandle message type @MessageType (@MessageContent)
	end try
	
	begin catch
		set @errorCode = error_number()
		set @ErrorMessage = error_message()
	end catch
end
go