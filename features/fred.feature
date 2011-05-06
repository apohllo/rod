Feature: ROD Storage
  In order to persist data
  Potential users
  Must be able to store and load their objects.
  Background:
    Given the library works in development mode
    And the class space is cleared
    And a class Fred has an age field of type integer
    And a class Fred has a sex field of type string with flat index

  Scenario Outline: Store Fred and modify his age
    When database is created
    And I create a Fred
    And his age is '<init_age>'
    And I store him in the database
    And his age is '<grown_age>'
    And I reopen database for reading
    Then there should be 1 Fred
    And the age of the first Fred should be '<grown_age>'

    Examples:
      | init_age  | grown_age |
      | 2         | 3         |
      | 8         | 28        |

  Scenario Outline: Store a few Freds of different sexes. Count restored by sex.
    When database is created
    And I create a Fred
    And his sex is '<sex1>'
    And I store him in the database
    And I create another Fred
    And his sex is '<sex2>'
    And I store him in the database
    And I create another Fred
    And his sex is '<sex3>'
    And I store him in the database
    And I reopen database for reading
    Then database should be opened for reading
    And there should be <count1> Fred(s) with sex of value 'male'
    And there should be <count2> Fred(s) with sex of value 'female'

    Examples:
      | sex1  | sex2  | sex3    | count1  | count2  |
      | female| male  | female  | 1       | 2       |
      | male  | male  | female  | 2       | 1       |
