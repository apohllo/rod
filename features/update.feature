Feature: Update of the database
    This feature defines the update model of ROD.
  Background:
    Given the class space is cleared
    And the default database is initialized
    And the following classes are defined:
      """
      class Book
        include Rod.resource

        attribute :title, String, :index => :hash
      end

      class Automobile
        include Rod.resource

        attribute :name, String, :index => :hash
      end

      class Caveman
        include Rod.resource

        attribute :name, String, :index => :hash
        attribute :surname, String, :index => :hash
        attribute :login, String, :index => :hash
        attribute :age, Integer, :index => :hash
        attribute :identifier, Integer, :index => :hash
        attribute :height, Float, :index => :hash
      end
      """
    And a class User has a name field of type string with flat index
    And a class User has a surname field of type string with flat index
    And a class User has a login field of type string with flat index
    And a class User has an age field of type integer with flat index
    And a class User has a height field of type float with flat index
    And a class User has a sex field of type object with flat index
    And a class User has one automobile with flat index
    And a class User has many books with flat index
    And a class User has one polymorphic item with flat index
    And a class User has many polymorphic tools with flat index

  @wip
  Scenario: update of fields
    When database is created
    And I create and store the following User(s):
      | name | surname | login | age  | sex     | height |
      | John | Smith   | john  | 12   | :male   | 1.30   |
      | Lara | Croft   | lara  | 23   | :female | 2.00   |
      | Adam | Parker  | adam  | 17   | :male   | -1.00  |
      | Adam |         | noob1 | 33   | :male   | 1.50   |
      |      |         | noob2 | -1   |         | 0      |
    And I reopen database
    And I fetch the first User
    And his name is 'Jonhy' now
    And his name is 'Johnny' now
    And his login is 'johnny' now
    And his age is '13' now
    And his height is '1.50' now
    And I store him in the database
    And I fetch the third User
    And his name is 'Alen' now
    And his login is 'alen' now
    And his height is '1.51' now
    And I store him in the database
    And I fetch the fourth User
    And her name is 'Anna' now
    And her name is 'Nina' now
    And her login is 'nina' now
    And her age is '34' now
    And her sex is ':female' now
    And I store her in the database
    And I fetch the fifth User
    And her name is 'Anna' now
    And her login is 'anna' now
    And her age is '1' now
    And her sex is ':female' now
    And her height is '-1.51' now
    And I store her in the database
    And I reopen the database for reading
    Then there should be 5 User(s)
    And the name of the first User should be 'Johnny'
    And the surname of the first User should be 'Smith'
    And the login of the first User should be 'johnny'
    And the age of the first User should be '13'
    And the sex of the first User should be ':male'
    And the height of the first User should be '1.50'
    And the name of the second User should be 'Lara'
    And the surname of the second User should be 'Croft'
    And the login of the second User should be 'lara'
    And the age of the second User should be '23'
    And the sex of the second User should be ':female'
    And the height of the second User should be '2.00'
    And the name of the third User should be 'Alen'
    And the login of the third User should be 'alen'
    And the age of the third User should be '17'
    And the sex of the third User should be ':male'
    And the height of the third User should be '1.51'
    And the name of the fourth User should be 'Nina'
    And the surname of the fourth User should be ''
    And the login of the fourth User should be 'nina'
    And the age of the fourth User should be '34'
    And the sex of the fourth User should be ':female'
    And the height of the fourth User should be '1.50'
    And the name of the fifth User should be 'Anna'
    And the surname of the fifth User should be ''
    And the login of the fifth User should be 'anna'
    And the age of the fifth User should be '1'
    And the sex of the fifth User should be ':female'
    And the height of the fifth User should be '-1.51'

  Scenario: update of has one relatinships
    When database is created
    And I create a Book
    And its title is 'Gonne with the wind'
    And I store it in the database
    And I create another Book
    And its title is 'Thus Spoke Zarathustra'
    And I store it in the database
    And I create another Book
    And its title is 'Encyclopedia'
    And I store it in the database
    And I create an Automobile
    And its name is 'BMW 330'
    And I store it in the database
    And I create another Automobile
    And its name is 'Daewoo Tico'
    And I store it in the database
    And I create a User
    And his automobile is the first Automobile created
    And his item is the second Book created
    And I store him in the database
    And I create another User
    And his automobile is the second Automobile created
    And his item is the first Book created
    And I store him in the database
    # reopen
    And I reopen the database
    And I fetch the first User
    And his automobile is the second Automobile created
    And his item is the first Book created
    And his item is the third Book created
    And I store him in the database
    And I fetch the second User
    And his item is the second Book created
    And his item is the first Book created
    And I store him in the database
    And I reopen the database for reading
    Then there should be 2 User(s)
    And the automobile of the first User should be equal to the second Automobile
    And the item of the first User should be equal to the third Book
    And the automobile of the second User should be equal to the second Automobile
    And the item of the second User should be equal to the first Book

  Scenario: update of has many relatinships
    When database is created
    And I create a Book
    And its title is 'Gonne with the wind'
    And I store it in the database
    And I create another Book
    And its title is 'Thus Spoke Zarathustra'
    And I store it in the database
    And I create another Book
    And its title is 'Encyclopedia'
    And I store it in the database
    And I create an Automobile
    And its name is 'BMW 330'
    And I store it in the database
    And I create another Automobile
    And its name is 'Daewoo Tico'
    And I store it in the database
    And I create a User
    And his books contain the first Book created
    And his books contain the second Book created
    And his books contain the third Book created
    And his tools contain the third Book created
    And his tools contain the first Automobile created
    And I store him in the database
    And I create another User
    And I store him in the database
    # reopen
    And I reopen the database
    And I fetch the first User
    And I remove the first of his books
    And I remove the second of his books
    And I remove the second of his tools
    And I store him in the database
    And I fetch the second User
    And his books contain the first Book created
    And his tools contain the second Automobile created
    And his tools contain the first Automobile created
    And I remove the second of his tools
    And I store him in the database
    And I reopen the database for reading
    Then there should be 2 User(s)
    And the first User should have 1 books
    And the first of books of the first User should be equal to the second Book
    And the first User should have 1 tools
    And the first of tools of the first User should be equal to the third Book
    And the second User should have 1 books
    And the first of books of the second User should be equal to the first Book
    And the second User should have 1 tools
    And the first of tools of the second User should be equal to the second Automobile

  Scenario: update with indexing
    When database is created
    And I create a Book
    And its title is 'Gonne with the wind'
    And I store it in the database
    And I create another Book
    And its title is 'Thus Spoke Zarathustra'
    And I store it in the database
    And I create another Book
    And its title is 'Encyclopedia'
    And I store it in the database
    And I create an Automobile
    And its name is 'BMW 330'
    And I store it in the database
    And I create another Automobile
    And its name is 'Daewoo Tico'
    And I store it in the database
    And I create a User
    And his name is 'Johnny'
    And his login is 'johnny'
    And his age is '13'
    And his height is '1.50'
    And his sex is ':male'
    And his automobile is the first Automobile created
    And his item is the first Book created
    And his books contain the first Book created
    And his tools contain the first Automobile created
    And I store him in the database
    And I create another User
    And her name is 'Anna'
    And her login is 'anna'
    And her age is '23'
    And her height is '1.70'
    And her sex is ':female'
    And her automobile is the second Automobile created
    And her item is the second Book created
    And her books contain the second Book created
    And her books contain the third Book created
    And her tools contain the second Automobile created
    And I store her in the database
    # reopen
    And I reopen the database
    And I fetch the first User
    And her sex is ':female' now
    And her name is 'Joanna' now
    And her login is 'joanna' now
    And her age is '23' now
    And her height is '1.80' now
    And her automobile is the second Automobile created
    And her item is the second Book created
    And I remove the first of her books
    And I remove the first of her tools
    And her books contain the second Book created
    And her tools contain the second Automobile created
    And I store her in the database
    And I fetch the second User
    And her automobile is the first Automobile created
    And I remove the first of her books
    And I store her in the database
    And I reopen the database for reading
    Then there should be 2 User(s)
    And there should be 1 User(s) with 'Joanna' name
    And there should be 0 User(s) with 'Johnny' name
    And there should be 1 User(s) with 'Anna' name
    And there should be 1 User(s) with 'joanna' login
    And there should be 0 User(s) with 'johnny' login
    And there should be 1 User(s) with 'anna' login
    And there should be 2 User(s) with '23' age
    And there should be 0 User(s) with '13' age
    And there should be 1 User(s) with '1.80' height
    And there should be 0 User(s) with '1.50' height
    And there should be 1 User(s) with '1.70' height
    And there should be 2 User(s) with ':female' sex
    And there should be 0 User(s) with ':male' sex
    And there should be 1 User with the first Automobile as automobile
    And there should be 1 User with the second Automobile as automobile
    And there should be 0 User(s) with the first Book as item
    And there should be 2 User(s) with the second Book as item
    And there should be 0 User(s) with the first Automobile in their tools
    And there should be 2 User(s) with the second Automobile in their tools
    And there should be 0 User with the first Book in their books
    And there should be 1 User with the second Book in their books
    And there should be 1 User with the third Book in their books
