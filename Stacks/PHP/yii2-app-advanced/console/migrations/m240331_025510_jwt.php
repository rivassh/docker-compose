<?php

use yii\db\Migration;

/**
 * Class m240331_025510_jwt
 */
class m240331_025510_jwt extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {

        $this->createTable('user_refresh_tokens', [
            'user_refresh_tokenID' => $this->primaryKey(),
            'urf_userID' => $this->integer()->notNull(),
            'urf_token' => $this->string(1000)->notNull(),
            'urf_ip' => $this->string(50)->notNull(),
            'urf_user_agent' => $this->string(1000)->notNull(),
            'urf_created' => $this->date()->notNull(),

        ], );

    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        echo "m240331_025510_jwt cannot be reverted.\n";

        return false;
    }

    /*
    // Use up()/down() to run migration code without a transaction.
    public function up()
    {

    }

    public function down()
    {
        echo "m240331_025510_jwt cannot be reverted.\n";

        return false;
    }
    */
}
