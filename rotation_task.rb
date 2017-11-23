require 'bundler/setup'
require 'time'
require 'trello'
require 'dotenv'

Dotenv.load

# 認証
Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
  config.member_token = ENV['TRELLO_MEMBER_TOKEN']
end

# 変数設定
board       = Trello::Board.find(ENV['BOARD_ID'])
source_list = Trello::List.find(ENV['SOURCE_LIST'])
to_do_list  = Trello::List.find(ENV['TO_DO_LIST'])
done_list   = Trello::List.find(ENV['DONE_LIST'])

# ボードのメンバー情報取得
task_members = board.members

# メンバーをローテーション
rotation_count_card = source_list.cards.last
rotation_count = rotation_count_card.name.to_i
task_members.rotate!(rotation_count)

# 完了したto_do_listのカードをdone_listへ移動
to_do_list.cards.map{|card| card.move_to_list(done_list)}

# 新規カード作成 (source_listからto_do_listへカードをコピーしてメンバーを割り振り)
source_cards = source_list.cards
task_members.count.times do
  source_card = source_cards.shift
  Trello::Card.create(
    source_card_id: source_card.id,
    list_id: to_do_list.id,
  )
  member = task_members.shift
  to_do_list.cards.first.add_member(member)
end

# ローテーション回数を更新
rotation_count_card.delete if rotation_count_card.name =~ /^[0-9]+$/
if rotation_count >= board.members.count
  new_card_name = "0"
else
  new_card_name = "#{rotation_count + 1}"
end
Trello::Card.create(
  list_id: source_list.id,
  name: new_card_name,
  pos: "bottom",
)

# done_listで14日以上動きがないものを削除
done_list.cards.each do |card|
  card.delete if card.last_activity_date.to_date > Time.now.to_date + 14
end
